package com.example.roast_guard

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UsageStatsPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.roastguard/usage_stats"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsagePermission" -> result.success(hasUsagePermission())
            "requestUsagePermission" -> requestUsagePermission(result)
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(context))
            "requestOverlayPermission" -> requestOverlayPermission(result)
            "isBatteryOptimized" -> result.success(isBatteryOptimized())
            "requestBatteryOptimizationBypass" -> requestBatteryOptimizationBypass(result)
            "getUsageStats" -> getUsageStats(call, result)
            "getForegroundApp" -> result.success(getForegroundApp())
            "getInstalledApps" -> getInstalledApps(result)
            "startMonitorService" -> startMonitorService(result)
            "stopMonitorService" -> stopMonitorService(result)
            else -> result.notImplemented()
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsagePermission(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
        result.success(null)
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        )
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
        result.success(null)
    }

    private fun getUsageStats(call: MethodCall, result: MethodChannel.Result) {
        if (!hasUsagePermission()) {
            result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
            return
        }

        val hours = call.argument<Int>("hours") ?: 24
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - (hours * 60 * 60 * 1000L)

        val statsMap = usm.queryAndAggregateUsageStats(startTime, endTime)

        val resultList = statsMap.values
            .filter { it.totalTimeInForeground > 0 }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "totalTimeMs" to it.totalTimeInForeground,
                    "lastTimeUsed" to it.lastTimeUsed
                )
            }

        result.success(resultList)
    }

    private fun getForegroundApp(): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 10_000L,
            time
        )
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun startMonitorService(result: MethodChannel.Result) {
        val intent = Intent(context, ForegroundMonitorService::class.java)
        context.startForegroundService(intent)
        result.success(null)
    }

    private fun stopMonitorService(result: MethodChannel.Result) {
        val intent = Intent(context, ForegroundMonitorService::class.java)
        context.stopService(intent)
        result.success(null)
    }

    /// Returns true if battery optimization is DISABLED for this app
    /// (i.e. the app is already whitelisted / unrestricted).
    private fun isBatteryOptimized(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /// Prompts the user with the system dialog to disable battery optimization
    /// for this app. The dialog is shown by the OS — no custom UI needed.
    private fun requestBatteryOptimizationBypass(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
        result.success(null)
    }

    private fun getInstalledApps(result: MethodChannel.Result) {
        val pm = context.packageManager
        val packages = pm.getInstalledPackages(0)
        val resultList = packages
            .filter {
                val appInfo = it.applicationInfo
                appInfo != null && (
                    (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0 ||
                    (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                )
            }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "name" to (it.applicationInfo?.loadLabel(pm)?.toString() ?: it.packageName)
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { (it["name"] ?: "").lowercase() }
        result.success(resultList)
    }
}
