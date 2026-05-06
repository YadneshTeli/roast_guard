import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Roast intensity levels.
enum RoastIntensity {
  gentle('Gentle Nudge', '😊', 'A polite reminder'),
  medium('Moderate Shame', '😤', 'Gets the point across'),
  brutal('Full Intervention', '🔥', 'Nuclear option — no mercy');

  const RoastIntensity(this.label, this.emoji, this.description);

  final String label;
  final String emoji;
  final String description;
}

/// Provider for the current roast intensity setting.
final roastIntensityProvider =
    NotifierProvider<RoastIntensityNotifier, RoastIntensity>(
      RoastIntensityNotifier.new,
    );

class RoastIntensityNotifier extends Notifier<RoastIntensity> {
  @override
  RoastIntensity build() {
    _load();
    return RoastIntensity.medium;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('roast_intensity') ?? 1;
    state = RoastIntensity.values[index.clamp(0, 2)];
  }

  Future<void> setIntensity(RoastIntensity intensity) async {
    state = intensity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('roast_intensity', intensity.index);
  }
}

/// Provider for per-app time threshold (in minutes).
final thresholdMinutesProvider = NotifierProvider<ThresholdNotifier, int>(
  ThresholdNotifier.new,
);

class ThresholdNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 10;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('threshold_minutes') ?? 10;
  }

  Future<void> setThreshold(int minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('threshold_minutes', minutes);
  }
}
