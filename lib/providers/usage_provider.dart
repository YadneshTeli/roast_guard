import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/usage_service.dart';
import 'tracked_packages_provider.dart';

final usageServiceProvider = Provider((_) => UsageService());

final usageStatsProvider = FutureProvider<List<AppUsageStat>>((ref) async {
  final service = ref.read(usageServiceProvider);
  final stats = await service.getUsageStats(hours: 24);
  final trackedPackages = ref.watch(trackedPackagesProvider);
  return stats
      .where((stat) => trackedPackages.contains(stat.packageName))
      .toList();
});

final permissionStatusProvider = FutureProvider<PermissionStatus>((ref) async {
  final service = ref.read(usageServiceProvider);
  final hasUsage = await service.hasUsagePermission();
  final hasOverlay = await service.hasOverlayPermission();
  return PermissionStatus(hasUsage: hasUsage, hasOverlay: hasOverlay);
});

class PermissionStatus {
  final bool hasUsage;
  final bool hasOverlay;

  const PermissionStatus({required this.hasUsage, required this.hasOverlay});

  bool get allGranted => hasUsage && hasOverlay;
}
