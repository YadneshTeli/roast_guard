import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../../core/services/usage_service.dart';

class PermissionState {
  final bool hasUsage;
  final bool hasOverlay;
  final bool hasBattery;
  final bool isLoading;

  const PermissionState({
    this.hasUsage = false,
    this.hasOverlay = false,
    this.hasBattery = false,
    this.isLoading = false,
  });

  PermissionState copyWith({
    bool? hasUsage,
    bool? hasOverlay,
    bool? hasBattery,
    bool? isLoading,
  }) {
    return PermissionState(
      hasUsage: hasUsage ?? this.hasUsage,
      hasOverlay: hasOverlay ?? this.hasOverlay,
      hasBattery: hasBattery ?? this.hasBattery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get allGranted => hasUsage && hasOverlay && hasBattery;
}

class PermissionViewModel extends Notifier<PermissionState> {
  late final UsageService _usageService;

  @override
  PermissionState build() {
    _usageService = UsageService();
    // Schedule checkPermissions check after initialization
    Future.microtask(() => checkPermissions());
    return const PermissionState(isLoading: true);
  }

  Future<void> checkPermissions() async {
    final usage = await _usageService.hasUsagePermission();
    final overlay = await _usageService.hasOverlayPermission();
    final battery = await _usageService.isBatteryOptimized();
    state = PermissionState(
      hasUsage: usage,
      hasOverlay: overlay,
      hasBattery: battery,
      isLoading: false,
    );
  }

  Future<void> requestUsagePermission() async {
    await _usageService.requestUsagePermission();
    await checkPermissions();
  }

  Future<void> requestOverlayPermission() async {
    await _usageService.requestOverlayPermission();
    await checkPermissions();
  }

  Future<void> requestBatteryBypass() async {
    await _usageService.requestBatteryOptimizationBypass();
    await checkPermissions();
  }

  Future<bool> completeOnboarding() async {
    await FlutterForegroundTask.requestNotificationPermission();
    await _usageService.startMonitorService();
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool('onboarding_complete', true);
  }
}

final permissionViewModelProvider =
    NotifierProvider<PermissionViewModel, PermissionState>(
  PermissionViewModel.new,
);
