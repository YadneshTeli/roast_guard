import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/usage_provider.dart';

class DashboardViewModel {
  final Ref _ref;

  DashboardViewModel(this._ref);

  Future<void> toggleTracking(bool val) =>
      _ref.read(trackingEnabledProvider.notifier).toggleTracking(val);

  Future<void> toggleCustomThresholds(bool val) =>
      _ref.read(useCustomThresholdsProvider.notifier).toggle(val);

  Future<void> setRoastIntensity(RoastIntensity intensity) =>
      _ref.read(roastIntensityProvider.notifier).setIntensity(intensity);

  void refreshUsage() => _ref.invalidate(usageStatsProvider);
}

final dashboardViewModelProvider = Provider<DashboardViewModel>((ref) {
  return DashboardViewModel(ref);
});
