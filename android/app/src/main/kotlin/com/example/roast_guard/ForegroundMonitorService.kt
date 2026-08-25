package com.example.roast_guard

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class ForegroundMonitorService : Service() {

    companion object {
        private const val TAG = "RoastGuardMonitor"
    }

    private val handler = Handler(Looper.getMainLooper())
    private val pollInterval = 15_000L // 15 seconds for faster detection

    private val defaultTargetApps = setOf(
        "com.instagram.android",
        "com.twitter.android",
        "com.facebook.katana",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically",
        "com.reddit.frontpage",
        "com.snapchat.android"
    )

    private fun getTargetApps(): Set<String> {
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        try {
            val set = flutterPrefs.getStringSet("flutter.tracked_packages", null)
            if (set != null) {
                return set
            }
        } catch (e: ClassCastException) {
            // Key is stored as a String (JSON list with base64 prefix)
        }

        val rawString = flutterPrefs.getString("flutter.tracked_packages", null)
        if (rawString != null) {
            try {
                var jsonStr = rawString
                val index = jsonStr.indexOf("[")
                if (index != -1) {
                    jsonStr = jsonStr.substring(index)
                }
                val jsonArray = org.json.JSONArray(jsonStr)
                val resultSet = mutableSetOf<String>()
                for (i in 0 until jsonArray.length()) {
                    resultSet.add(jsonArray.getString(i))
                }
                return resultSet
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing tracked_packages JSON string", e)
            }
        }
        return defaultTargetApps
    }

    private var lastResetDay = -1

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                checkAndRoast()
            } catch (e: Exception) {
                Log.e(TAG, "Error during poll", e)
            }
            handler.postDelayed(this, pollInterval)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        createNotificationChannel()
        startForeground(1, buildNotification())

        resetIfNewDay()

        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        Log.d(TAG, "Monitor service started, polling every ${pollInterval / 1000}s")
        return START_NOT_STICKY   // Do not auto-restart; the toggle controls restarts
    }

    /**
     * Read the per-app time threshold from Flutter's SharedPreferences.
     * Flutter stores the value as INT (setInt), so we must read it with getInt
     * and widen to Long — using getLong would return the default on some devices
     * because the stored type tag is INT, not LONG.
     */
    private fun getPrefsIntOrLong(prefs: android.content.SharedPreferences, key: String, defaultValue: Int): Int {
        try {
            return prefs.getInt(key, defaultValue)
        } catch (e: ClassCastException) {
            try {
                return prefs.getLong(key, defaultValue.toLong()).toInt()
            } catch (e2: ClassCastException) {
                val str = prefs.getString(key, null)
                if (str != null) {
                    return str.toIntOrNull() ?: defaultValue
                }
            }
        }
        return defaultValue
    }

    private fun getThresholdMs(currentApp: String): Long {
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val useCustom = flutterPrefs.getBoolean("flutter.use_custom_thresholds", false)
        val minutes = if (useCustom) {
            val custom = getPrefsIntOrLong(flutterPrefs, "flutter.custom_threshold_${currentApp}_minutes", -1)
            if (custom != -1) custom.toLong() else getPrefsIntOrLong(flutterPrefs, "flutter.threshold_minutes", 10).toLong()
        } else {
            getPrefsIntOrLong(flutterPrefs, "flutter.threshold_minutes", 10).toLong()
        }
        Log.d(TAG, "Threshold for $currentApp: ${minutes}m (${minutes * 60 * 1000}ms)")
        return minutes * 60 * 1000L
    }

    private fun resetIfNewDay() {
        val today = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
        if (today != lastResetDay) {
            lastResetDay = today
            Log.d(TAG, "New day — reset tracking")
        }
    }

    private fun checkAndRoast() {
        resetIfNewDay()

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        
        // Suppress overlay blasts if tracking is disabled
        val trackingEnabled = flutterPrefs.getBoolean("flutter.tracking_enabled", true)
        if (!trackingEnabled) {
            Log.d(TAG, "Active monitoring is disabled in settings")
            return
        }

        val nextAllowedTime = flutterPrefs.getLong("flutter.next_allowed_roast_time", 0L)
        if (System.currentTimeMillis() < nextAllowedTime) {
            val remainingSec = (nextAllowedTime - System.currentTimeMillis()) / 1000
            Log.d(TAG, "In cooldown grace period ($remainingSec s remaining)")
            return
        }

        val currentApp = getCurrentForegroundApp()
        val targetApps = getTargetApps()
        Log.d(TAG, "Poll tick: CurrentForeground='$currentApp', TargetApps=$targetApps")

        if (currentApp == null || currentApp !in targetApps) {
            return
        }

        // Do not roast if the user is inside Doom Roast itself
        if (currentApp == packageName) {
            return
        }

        val totalMs = getAppUsageToday(currentApp)
        val thresholdMs = getThresholdMs(currentApp)

        Log.d(TAG, "Target app in foreground: $currentApp | Today's Usage: ${totalMs / 1000}s (${totalMs / 60000}m) | Threshold: ${thresholdMs / 1000}s (${thresholdMs / 60000}m)")

        if (totalMs >= thresholdMs) {
            Log.d(TAG, "💥 THRESHOLD EXCEEDED for $currentApp — triggering roast overlay!")
            triggerRoast(currentApp, totalMs)
        }
    }

    /**
     * Uses UsageEvents with 2-hour window and fallback to accurately find the ACTUAL current foreground app.
     */
    private fun getCurrentForegroundApp(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 2 * 60 * 60 * 1000L, now)

        var lastForegroundApp: String? = null
        var lastForegroundTime = 0L
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // Event.MOVE_TO_FOREGROUND (1) or Event.ACTIVITY_RESUMED (1)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND || event.eventType == 1) {
                if (event.timeStamp >= lastForegroundTime) {
                    lastForegroundTime = event.timeStamp
                    lastForegroundApp = event.packageName
                }
            } else if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND || event.eventType == 2 || event.eventType == 23) {
                if (event.timeStamp >= lastForegroundTime && event.packageName == lastForegroundApp) {
                    lastForegroundApp = null
                }
            }
        }

        // Fallback: Query the most recently active package in the last 30 seconds
        if (lastForegroundApp == null) {
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 30_000L, now)
            lastForegroundApp = stats?.filter { it.lastTimeUsed > now - 30_000L }?.maxByOrNull { it.lastTimeUsed }?.packageName
        }

        return lastForegroundApp
    }

    /**
     * Gets aggregated usage time for an app across the past 24 hours.
     */
    private fun getAppUsageToday(packageName: String): Long {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val statsMap = usm.queryAndAggregateUsageStats(now - 24 * 60 * 60 * 1000L, now)
        return statsMap[packageName]?.totalTimeInForeground ?: 0L
    }

    private fun triggerRoast(packageName: String, totalMs: Long) {
        if (!android.provider.Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot trigger roast overlay: Display Over Other Apps permission is NOT granted!")
            return
        }

        val todayStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putString("flutter.last_broken_date", todayStr)
            // Signal Flutter to prefetch the NEXT roast. Two consumers:
            // 1. AppLifecycleListener.onResume (immediate, if app is opened)
            // 2. Periodic WorkManager task (background, ~15 min interval)
            .putString(OverlayService.KEY_PREFETCH_PENDING, packageName)
            .apply()

        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra("package_name", packageName)
            putExtra("total_ms", totalMs)
        }
        startService(intent)
    }

    private fun createNotificationChannel() {
        val channelId = "roastguard_monitor"
        val channel = NotificationChannel(
            channelId, "RoastGuard Monitor",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Monitoring your screen time habits"
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, "roastguard_monitor")
            .setContentTitle("RoastGuard is watching 👀")
            .setContentText("Monitoring your scroll habits...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Re-schedule the service to restart if the app task is removed
        val restartIntent = Intent(applicationContext, ForegroundMonitorService::class.java)
        val pendingIntent = android.app.PendingIntent.getService(
            applicationContext, 1, restartIntent,
            android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.set(
            android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + 1000,
            pendingIntent
        )
        Log.d(TAG, "Task removed — scheduled service restart")
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        stopForeground(true)
        Log.d(TAG, "Monitor service destroyed")
        super.onDestroy()
    }
}
