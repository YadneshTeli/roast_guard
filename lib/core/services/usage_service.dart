import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Service to communicate with the native UsageStatsPlugin via MethodChannel,
/// and manage the foreground monitoring service via flutter_foreground_task.
class UsageService {
  static const _channel = MethodChannel('com.roastguard/usage_stats');

  Future<bool> hasUsagePermission() async {
    return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
  }

  Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  Future<List<AppUsageStat>> getUsageStats({int hours = 24}) async {
    final raw = await _channel.invokeListMethod<Map>('getUsageStats', {
      'hours': hours,
    });
    return raw
            ?.map((e) => AppUsageStat.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  Future<String?> getForegroundApp() async {
    return await _channel.invokeMethod<String>('getForegroundApp');
  }

  /// Start the native foreground monitoring service.
  /// Uses FlutterForegroundTask for proper lifecycle management on the Dart side,
  /// then delegates to the existing Kotlin ForegroundMonitorService via the channel.
  Future<void> startMonitorService() async {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'RoastGuard is watching 👀',
      notificationText: 'Monitoring your scroll habits...',
    );
    // Also notify the existing Kotlin channel so ForegroundMonitorService
    // knows to start polling (the task handler runs alongside it).
    try {
      await _channel.invokeMethod('startMonitorService');
    } catch (_) {}
  }

  /// Stop the foreground monitoring service.
  Future<void> stopMonitorService() async {
    await FlutterForegroundTask.stopService();
    try {
      await _channel.invokeMethod('stopMonitorService');
    } catch (_) {}
  }
}

/// Represents usage stats for a single app.
class AppUsageStat {
  final String packageName;
  final Duration totalTime;
  final DateTime lastUsed;

  AppUsageStat({
    required this.packageName,
    required this.totalTime,
    required this.lastUsed,
  });

  factory AppUsageStat.fromMap(Map<String, dynamic> map) {
    return AppUsageStat(
      packageName: map['packageName'] as String,
      totalTime: Duration(milliseconds: (map['totalTimeMs'] as num).toInt()),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(
        (map['lastTimeUsed'] as num).toInt(),
      ),
    );
  }
}
