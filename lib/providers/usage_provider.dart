import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/usage_service.dart';

final usageServiceProvider = Provider((_) => UsageService());

final usageStatsProvider = FutureProvider<List<AppUsageStat>>((ref) async {
  final service = ref.read(usageServiceProvider);
  return service.getUsageStats(hours: 24);
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
