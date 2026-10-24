import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_packages.dart';
import '../../providers/config_provider.dart';
import 'gemma_service.dart';
import 'groq_service.dart';
import 'usage_service.dart';

/// Generates roasts using the user-selected [AiProvider], falling back to the
/// other provider, then to a curated static roast. Never throws.
///
/// Reads the provider choice straight from SharedPreferences (not Riverpod) so
/// it also works inside the WorkManager background isolate.
class RoastAiService {
  RoastAiService._();

  static final _fallbacks = <String, List<String>>{
    'com.instagram.android': [
      "You've been on Instagram for {time}. The algorithm is winning. You are losing.",
      "Congrats, {time} watching people who are actually doing things.",
      "{time} of reels. Zero reels of your own life recorded.",
    ],
    'com.twitter.android': [
      "{time} on Twitter. You haven't changed a single mind. Log off.",
      "Breaking: Local person wastes {time} arguing with strangers online.",
    ],
    'com.facebook.katana': [
      "{time} on Facebook. Are you okay?",
      "{time} of Facebook. You are becoming your parents. This is not a compliment.",
    ],
    'com.google.android.youtube': [
      "{time} on YouTube. You started with one video. Classic.",
      "{time} of YouTube. You could have built something. Instead you watched someone else build.",
    ],
    'com.zhiliaoapp.musically': [
      "{time} on TikTok. Your attention span is now 3 seconds. Congratulations.",
      "You've lost {time} to 15-second videos. Do the math.",
    ],
    'com.reddit.frontpage': [
      "{time} on Reddit. You've learned a lot about things that don't matter.",
      "AMA: How does it feel to waste {time} of your potential?",
    ],
    'com.snapchat.android': [
      "{time} on Snapchat. Those streaks won't help your resume.",
      "You spent {time} sending disappearing messages. Much like your productivity.",
    ],
  };

  // ---------------------------------------------------------------------------
  // Provider routing
  // ---------------------------------------------------------------------------

  // Lazily fetched SharedPreferences instance
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<AiProvider> _selectedProvider() async {
    final prefs = await _getPrefs();
    return AiProvider.fromIndex(prefs.getInt(AiProvider.prefsKey));
  }

  static bool get _anyConfigured =>
      GemmaService.isConfigured || GroqService.isConfigured;

  /// Selected provider first, the other as fallback. Returns `null` only if
  /// both fail or neither has an API key.
  static Future<String?> _complete({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
    bool weekly = false,
  }) async {
    final primary = await _selectedProvider();
    final order = primary == AiProvider.gemma
        ? [AiProvider.gemma, AiProvider.groq]
        : [AiProvider.groq, AiProvider.gemma];

    for (final provider in order) {
      final result = switch (provider) {
        AiProvider.gemma => await GemmaService.complete(
          system: system,
          user: user,
          temperature: temperature,
          // Gemma tends to be wordier — give it a little headroom
          maxTokens: maxTokens + 40,
        ),
        AiProvider.groq => await GroqService.complete(
          system: system,
          user: user,
          temperature: temperature,
          maxTokens: maxTokens,
          weekly: weekly,
        ),
      };
      if (result != null && result.isNotEmpty) return result;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate an AI roast for [packageName] given [time] spent and [intensity].
  /// Returns the AI roast string, or a static fallback on error.
  static Future<String> getRoast(
    String packageName,
    Duration time,
    RoastIntensity intensity,
  ) async {
    final timeStr = _formatDuration(time);
    final appName = AppPackages.getMeta(packageName).name;

    try {
      final content = await _complete(
        system: _getSystemPrompt(intensity),
        user:
            'Roast me. I just spent $timeStr on $appName. '
            '${_timeOfDayContext()} '
            'Make it sting but keep it funny. Two sentences max.',
        temperature: 0.9,
        maxTokens: 120,
      );
      if (content != null) return content;
    } catch (_) {
      // Any other error → silent fallback
    }

    return _fallback(packageName, timeStr);
  }

  /// Pre-fetches one AI roast per tracked app and caches each into
  /// SharedPreferences under the key `cached_roast_{packageName}`.
  /// Called at app startup so OverlayService can show roasts instantly.
  static Future<void> prefetchRoasts(RoastIntensity intensity) async {
    if (!_anyConfigured) return;

    final prefs = await _getPrefs();
    final tracked =
        prefs.getStringList('tracked_packages') ??
        AppPackages.targets.keys.toList();

    for (final packageName in tracked) {
      // Skip if a cached roast is already waiting (not yet consumed)
      final existing = prefs.getString('cached_roast_$packageName');
      if (existing != null && existing.isNotEmpty) continue;

      await prefetchSingleRoast(packageName, intensity);
    }
  }

  /// Fetches a single AI roast for [packageName] and caches it into
  /// SharedPreferences. Unlike [prefetchRoasts], this always fetches
  /// (no skip-if-exists check) because the cache was just consumed.
  /// Used by the background worker and onResume handler after an overlay
  /// dismissal to replenish the cache for that specific app.
  static Future<void> prefetchSingleRoast(
    String packageName,
    RoastIntensity intensity,
  ) async {
    if (!_anyConfigured) return;

    final appName = AppPackages.getMeta(packageName).name;

    try {
      final content = await _complete(
        system: _getSystemPrompt(intensity),
        user:
            'Write ONE brutal roast (2 sentences max) for someone '
            'who spends too much time on $appName. Be sharp, witty, specific.',
        temperature: 0.95,
        maxTokens: 120,
      );

      if (content != null) {
        final prefs = await _getPrefs();
        await prefs.setString('cached_roast_$packageName', content);
      }
    } catch (_) {
      // Overlay will use static fallback — that is fine
    }
  }

  static Future<String> getWeeklyRoast(
    List<AppUsageStat> stats,
    RoastIntensity intensity,
  ) async {
    if (!_anyConfigured) {
      return "Wow, you spent all this time scrolling but couldn't be bothered to set an API key. Typical.";
    }

    final usageSummary = stats
        .map((e) {
          final appName = AppPackages.getMeta(e.packageName).name;
          return '$appName: ${_formatDuration(e.totalTime)}';
        })
        .join(', ');

    if (usageSummary.isEmpty) {
      return "You didn't use any targeted apps this week. Either you're an absolute saint, or you uninstalled the apps to hide your shame.";
    }

    try {
      final content = await _complete(
        system:
            'You are a brutally honest productivity coach. Give a brutal '
            '3-sentence summary roast based on this person\'s weekly app '
            'usage. Be specific about the apps and times. No emojis. No hashtags.',
        user: 'Here is my weekly screen time: $usageSummary',
        temperature: 0.8,
        maxTokens: 250,
        weekly: true,
      );
      if (content != null) return content;
    } catch (_) {
      // Fall through to fallback message
    }

    return "I tried to roast your weekly usage, but the API crashed trying to comprehend that much wasted time.";
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _fallback(String packageName, String timeStr) {
    final list = List<String>.of(
      _fallbacks[packageName] ??
          [
            'You spent $timeStr staring at a screen. Your ancestors hunted mammoths. Think about that.',
            '$timeStr of your finite life. Gone. What did you gain? A sore thumb?',
          ],
    )..shuffle();
    return list.first.replaceAll('{time}', timeStr);
  }

  /// Gives the model something extra to riff on beyond app + duration.
  static String _timeOfDayContext() {
    final now = DateTime.now();
    final hour = now.hour;
    final clock =
        '${hour % 12 == 0 ? 12 : hour % 12}:${now.minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'AM' : 'PM'}';

    final vibe = switch (hour) {
      >= 0 && < 5 => 'It is the middle of the night and I should be asleep.',
      >= 5 && < 9 => 'It is early morning — I have barely started my day.',
      >= 9 && < 18 => 'It is working hours — I should be productive.',
      >= 18 && < 22 => 'It is evening — prime time I could spend on hobbies or people.',
      _ => 'It is late night and I have to wake up tomorrow.',
    };
    return 'The time is $clock. $vibe';
  }

  static String _getSystemPrompt(RoastIntensity intensity) {
    const base =
        'You are a brutally honest but funny productivity coach who roasts people '
        'for wasting time on social media. Your roasts are sharp, specific, and '
        'under 2 sentences. No emojis. No hashtags. Reply with the roast only. ';

    switch (intensity) {
      case RoastIntensity.gentle:
        return '$base'
            'Keep the tone lighthearted, sarcastic, and mildly judging. '
            'Do not be overly mean.';
      case RoastIntensity.medium:
        return '$base'
            'Be firm and shaming. Make them feel slightly embarrassed for '
            'wasting their precious time.';
      case RoastIntensity.brutal:
        return '$base'
            'Go absolutely nuclear. Destroy their ego. Be extremely savage, '
            'insulting their life choices and potential without holding back. '
            'Just raw, witty, brutal truth.';
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
