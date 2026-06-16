import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/usage_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/tracked_packages_provider.dart';
import '../../../core/services/groq_service.dart';
import '../../../core/services/usage_service.dart';

final weeklyStatsProvider = FutureProvider<List<AppUsageStat>>((ref) async {
  final service = ref.read(usageServiceProvider);
  final stats = await service.getUsageStats(hours: 168); // 7 days
  final trackedPackages = ref.watch(trackedPackagesProvider);
  return stats
      .where((stat) => trackedPackages.contains(stat.packageName))
      .toList();
});

final weeklyRoastProvider = FutureProvider<String>((ref) async {
  final stats = await ref.watch(weeklyStatsProvider.future);
  final intensity =
      ref.watch(roastIntensityProvider).value ?? RoastIntensity.brutal;
  return GroqService.getWeeklyRoast(stats, intensity);
});

class WeeklyReportViewModel {
  final Ref _ref;

  WeeklyReportViewModel(this._ref);

  void refresh() {
    _ref.invalidate(weeklyStatsProvider);
    _ref.invalidate(weeklyRoastProvider);
  }
}

final weeklyReportViewModelProvider = Provider<WeeklyReportViewModel>((ref) {
  return WeeklyReportViewModel(ref);
});
