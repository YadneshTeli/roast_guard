import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';

import '../../core/constants/app_packages.dart';
import '../../providers/config_provider.dart';

/// Calls the GROQ API to generate a brutally funny AI roast.
/// Falls back to a curated static roast on any error.
class GroqService {
  GroqService._();

  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  static final _dio =
      Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
          ),
        )
        ..interceptors.add(
          PrettyDioLogger(
            requestHeader: true,
            requestBody: true,
            responseBody: true,
            responseHeader: false,
            error: true,
            compact: true,
            maxWidth: 90,
          ),
        );

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

  /// Generate an AI roast for [packageName] given [time] spent and [intensity].
  /// Returns the AI roast string, or a static fallback on error.
  static Future<String> getRoast(
    String packageName,
    Duration time,
    RoastIntensity intensity,
  ) async {
    final timeStr = _formatDuration(time);
    final appName = AppPackages.targets[packageName]?.name ?? 'social media';

    try {
      final apiKey = dotenv.env['GROQ_API'];
      if (apiKey == null || apiKey.isEmpty) {
        return _fallback(packageName, timeStr);
      }

      final response = await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $apiKey',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {'role': 'system', 'content': _getSystemPrompt(intensity)},
            {
              'role': 'user',
              'content':
                  'Roast me. I just spent $timeStr on $appName. '
                  'Make it sting but keep it funny. Two sentences max.',
            },
          ],
          'temperature': 0.9,
          'max_tokens': 80,
        },
      );

      final content =
          response.data?['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }
    } on DioException {
      // Network / timeout / auth error → silent fallback
    } catch (_) {
      // Any other error → silent fallback
    }

    return _fallback(packageName, timeStr);
  }

  /// Pre-fetches one AI roast per tracked app and caches each into
  /// SharedPreferences under the key `cached_roast_{packageName}`.
  /// Called at app startup so OverlayService can show roasts instantly.
  static Future<void> prefetchRoasts(RoastIntensity intensity) async {
    final apiKey = dotenv.env['GROQ_API'];
    if (apiKey == null || apiKey.isEmpty) return;

    final prefs = await _getPrefs();

    for (final entry in AppPackages.targets.entries) {
      final packageName = entry.key;
      final appName = entry.value.name;

      // Skip if a cached roast is already waiting (not yet consumed)
      final existing = prefs.getString('cached_roast_$packageName');
      if (existing != null && existing.isNotEmpty) continue;

      try {
        final response = await _dio.post<Map<String, dynamic>>(
          _baseUrl,
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
          ),
          data: {
            'model': _model,
            'messages': [
              {'role': 'system', 'content': _getSystemPrompt(intensity)},
              {
                'role': 'user',
                'content':
                    'Write ONE brutal roast (2 sentences max) for someone '
                    'who spends too much time on $appName. Be sharp, witty, specific.',
              },
            ],
            'temperature': 0.95,
            'max_tokens': 80,
          },
        );

        final content =
            response.data?['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          await prefs.setString('cached_roast_$packageName', content.trim());
        }
      } catch (_) {
        // Skip this app on any error — overlay will use static fallback
      }
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
    final apiKey = dotenv.env['GROQ_API'];
    if (apiKey == null || apiKey.isEmpty) return;

    final appName = AppPackages.targets[packageName]?.name ?? 'social media';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $apiKey',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {'role': 'system', 'content': _getSystemPrompt(intensity)},
            {
              'role': 'user',
              'content':
                  'Write ONE brutal roast (2 sentences max) for someone '
                  'who spends too much time on $appName. Be sharp, witty, specific.',
            },
          ],
          'temperature': 0.95,
          'max_tokens': 80,
        },
      );

      final content =
          response.data?['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        final prefs = await _getPrefs();
        await prefs.setString('cached_roast_$packageName', content.trim());
      }
    } catch (_) {
      // Overlay will use static fallback — that is fine
    }
  }

  // Lazily fetched SharedPreferences instance
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static String _fallback(String packageName, String timeStr) {
    final list =
        _fallbacks[packageName] ??
        [
          'You spent $timeStr staring at a screen. Your ancestors hunted mammoths. Think about that.',
          '$timeStr of your finite life. Gone. What did you gain? A sore thumb?',
        ];
    list.shuffle();
    return list.first.replaceAll('{time}', timeStr);
  }

  static String _getSystemPrompt(RoastIntensity intensity) {
    const base =
        'You are a brutally honest but funny productivity coach who roasts people '
        'for wasting time on social media. Your roasts are sharp, specific, and '
        'under 2 sentences. No emojis. No hashtags. ';

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

  static Future<String> getWeeklyRoast(
    List<AppUsageStat> stats,
    RoastIntensity intensity,
  ) async {
    final apiKey = dotenv.env['GROQ_API'];
    if (apiKey == null || apiKey.isEmpty) {
      return "Wow, you spent all this time scrolling but couldn't be bothered to set an API key. Typical.";
    }

    final usageSummary = stats
        .map((e) {
          final appName =
              AppPackages.targets[e.packageName]?.name ?? e.packageName;
          return '$appName: ${_formatDuration(e.totalTime)}';
        })
        .join(', ');

    if (usageSummary.isEmpty) {
      return "You didn't use any targeted apps this week. Either you're an absolute saint, or you uninstalled the apps to hide your shame.";
    }

    try {
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a brutally honest productivity coach. Give a brutal 3-sentence summary roast based on this person\'s weekly app usage. Be specific about the apps and times. No emojis. No hashtags.',
            },
            {
              'role': 'user',
              'content': 'Here is my weekly screen time: $usageSummary',
            },
          ],
          'temperature': 0.8,
          'max_tokens': 150,
        },
      );

      final content = response.data['choices'][0]['message']['content'];
      return content.toString().trim();
    } catch (e) {
      return "I tried to roast your weekly usage, but the API crashed trying to comprehend that much wasted time.";
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
