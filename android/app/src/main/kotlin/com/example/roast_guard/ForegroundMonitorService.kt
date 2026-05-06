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

    private val targetApps = setOf(
        "com.instagram.android",
        "com.twitter.android",
        "com.facebook.katana",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically",
        "com.reddit.frontpage",
        "com.snapchat.android"
    )

    // Track which apps have already been roasted today to avoid spam
    private val roastedApps = mutableSetOf<String>()
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

        // Reset roasted apps daily
        resetIfNewDay()

        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        Log.d(TAG, "Monitor service started, polling every ${pollInterval / 1000}s")
        return START_STICKY
    }

    private fun getThresholdMs(): Long {
        // Read from Flutter's SharedPreferences (file: FlutterSharedPreferences, keys prefixed with "flutter.")
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val minutes = flutterPrefs.getLong("flutter.threshold_minutes", 10L)
        Log.d(TAG, "Threshold: ${minutes}m (${minutes * 60 * 1000}ms)")
        return minutes * 60 * 1000L
    }

    private fun resetIfNewDay() {
        val today = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
        if (today != lastResetDay) {
            roastedApps.clear()
            lastResetDay = today
            Log.d(TAG, "New day — reset roasted apps")
        }
    }

    private fun checkAndRoast() {
        resetIfNewDay()

        val currentApp = getCurrentForegroundApp()
        if (currentApp == null || currentApp !in targetApps) {
            return
        }

        // Already roasted this app today
        if (currentApp in roastedApps) {
            return
        }

        // Query actual usage time from Android's UsageStatsManager
        val totalMs = getAppUsageToday(currentApp)
        val thresholdMs = getThresholdMs()

        Log.d(TAG, "App: $currentApp, Usage: ${totalMs / 1000}s, Threshold: ${thresholdMs / 1000}s")

        if (totalMs >= thresholdMs) {
            Log.d(TAG, "THRESHOLD EXCEEDED for $currentApp — triggering roast!")
            triggerRoast(currentApp, totalMs)
            roastedApps.add(currentApp)
        }
    }

    /**
     * Uses UsageEvents to find the ACTUAL current foreground app.
     * This is far more reliable than queryUsageStats for real-time detection.
     */
    private fun getCurrentForegroundApp(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        // Query events from the last 5 minutes to find the most recent MOVE_TO_FOREGROUND
        val events = usm.queryEvents(now - 5 * 60 * 1000L, now)

        var lastForegroundApp: String? = null
        var lastForegroundTime = 0L
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                if (event.timeStamp > lastForegroundTime) {
                    lastForegroundTime = event.timeStamp
                    lastForegroundApp = event.packageName
                }
            }
        }

        return lastForegroundApp
    }

    /**
     * Gets actual usage time for an app today, tracked by Android itself.
     * No in-memory state needed — survives service restarts.
     */
    private fun getAppUsageToday(packageName: String): Long {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Get start of today
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.timeInMillis
        val now = System.currentTimeMillis()

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now)
        return stats?.firstOrNull { it.packageName == packageName }?.totalTimeInForeground ?: 0L
    }

    private fun triggerRoast(packageName: String, totalMs: Long) {
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
