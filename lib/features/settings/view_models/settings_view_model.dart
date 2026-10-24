import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/roast_ai_service.dart';
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

  Future<void> setAiProvider(AiProvider provider) async {
    await _ref.read(aiProviderProvider.notifier).setProvider(provider);
    final intensity = await _ref.read(roastIntensityProvider.future);
    unawaited(RoastAiService.prefetchRoasts(intensity));
  }
}

final settingsViewModelProvider = Provider<SettingsViewModel>((ref) {
  return SettingsViewModel(ref);
});
