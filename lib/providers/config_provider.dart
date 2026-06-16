import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Shared SharedPreferences instance — initialized once, shared by all notifiers
// ---------------------------------------------------------------------------

/// Provides the app-wide SharedPreferences instance.
/// AsyncNotifier ensures it is awaited once and cached for the lifetime of the app.
final sharedPreferencesProvider =
    AsyncNotifierProvider<_SharedPreferencesNotifier, SharedPreferences>(
      _SharedPreferencesNotifier.new,
    );

class _SharedPreferencesNotifier extends AsyncNotifier<SharedPreferences> {
  @override
  Future<SharedPreferences> build() => SharedPreferences.getInstance();
}

// ---------------------------------------------------------------------------
// Roast intensity
// ---------------------------------------------------------------------------

enum RoastIntensity {
  gentle('Gentle Nudge', '😊', 'A polite reminder'),
  medium('Moderate Shame', '😤', 'Gets the point across'),
  brutal('Full Intervention', '🔥', 'Nuclear option — no mercy');

  const RoastIntensity(this.label, this.emoji, this.description);

  final String label;
  final String emoji;
  final String description;
}

final roastIntensityProvider =
    AsyncNotifierProvider<RoastIntensityNotifier, RoastIntensity>(
      RoastIntensityNotifier.new,
    );

class RoastIntensityNotifier extends AsyncNotifier<RoastIntensity> {
  @override
  Future<RoastIntensity> build() async {
    // Await the shared prefs instance (cached after first call)
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final index = prefs.getInt('roast_intensity') ?? 1;
    return RoastIntensity.values[index.clamp(0, 2)];
  }

  Future<void> setIntensity(RoastIntensity intensity) async {
    // Optimistic update — UI responds immediately
    state = AsyncData(intensity);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('roast_intensity', intensity.index);
  }
}

// ---------------------------------------------------------------------------
// Threshold minutes
// ---------------------------------------------------------------------------

final thresholdMinutesProvider = AsyncNotifierProvider<ThresholdNotifier, int>(
  ThresholdNotifier.new,
);

class ThresholdNotifier extends AsyncNotifier<int> {
  static const _channel = MethodChannel('com.roastguard/usage_stats');

  @override
  Future<int> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getInt('threshold_minutes') ?? 10;
  }

  Future<void> setThreshold(int minutes) async {
    state = AsyncData(minutes);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('threshold_minutes', minutes);
    try {
      await _channel.invokeMethod('startMonitorService');
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Tracking enabled
// ---------------------------------------------------------------------------

final trackingEnabledProvider =
    AsyncNotifierProvider<TrackingEnabledNotifier, bool>(
      TrackingEnabledNotifier.new,
    );

class TrackingEnabledNotifier extends AsyncNotifier<bool> {
  static const _channel = MethodChannel('com.roastguard/usage_stats');

  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool('tracking_enabled') ?? true;
  }

  Future<void> toggleTracking(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('tracking_enabled', enabled);
    if (enabled) {
      try {
        await _channel.invokeMethod('startMonitorService');
      } catch (_) {}
    }
  }
}

// ---------------------------------------------------------------------------
// Custom Thresholds Enabled
// ---------------------------------------------------------------------------

final useCustomThresholdsProvider =
    AsyncNotifierProvider<UseCustomThresholdsNotifier, bool>(
      UseCustomThresholdsNotifier.new,
    );

class UseCustomThresholdsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool('use_custom_thresholds') ?? false;
  }

  Future<void> toggle(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('use_custom_thresholds', enabled);
  }
}

// ---------------------------------------------------------------------------
// Per-App Custom Thresholds
// ---------------------------------------------------------------------------

final customThresholdProvider = FutureProvider.family<int, String>((
  ref,
  arg,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getInt('custom_threshold_${arg}_minutes') ?? -1;
});

// ---------------------------------------------------------------------------
// Theme Mode
// ---------------------------------------------------------------------------

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final index = prefs.getInt('theme_mode') ?? 0; // default is ThemeMode.system
    return ThemeMode.values[index.clamp(0, 2)];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('theme_mode', mode.index);
  }
}

