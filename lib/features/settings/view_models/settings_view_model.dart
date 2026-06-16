import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/config_provider.dart';

class SettingsViewModel {
  final Ref _ref;

  SettingsViewModel(this._ref);

  Future<void> setThreshold(int minutes) =>
      _ref.read(thresholdMinutesProvider.notifier).setThreshold(minutes);

  Future<void> setCustomAppThreshold(String packageName, int minutes) async {
    final prefs = _ref.read(sharedPreferencesProvider).requireValue;
    await prefs.setInt('custom_threshold_${packageName}_minutes', minutes);
    _ref.invalidate(customThresholdProvider(packageName));
  }
}

final settingsViewModelProvider = Provider<SettingsViewModel>((ref) {
  return SettingsViewModel(ref);
});
