package com.example.roast_guard

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class ForegroundMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val pollInterval = 30_000L // 30 seconds

    private val targetApps = setOf(
        "com.instagram.android",
        "com.twitter.android",
        "com.facebook.katana",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically",
        "com.reddit.frontpage",
        "com.snapchat.android"
    )

    private var lastForegroundApp: String? = null
    private var sessionStart: Long = 0L
    private val usageMap = mutableMapOf<String, Long>()
    private val roastedApps = mutableSetOf<String>()

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, pollInterval)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(1, buildNotification())
        loadThresholds()
        handler.post(pollRunnable)
        return START_STICKY
    }

    private fun getThresholdMs(): Long {
        val prefs = getSharedPreferences("roastguard_prefs", MODE_PRIVATE)
        return prefs.getLong("threshold_ms", 10 * 60 * 1000L) // default 10 minutes
    }

    private fun loadThresholds() {
        // Reset daily at midnight
        val prefs = getSharedPreferences("roastguard_prefs", MODE_PRIVATE)
        val lastReset = prefs.getLong("last_reset", 0L)
        val now = System.currentTimeMillis()
        val oneDayMs = 24 * 60 * 60 * 1000L
        if (now - lastReset > oneDayMs) {
            usageMap.clear()
            roastedApps.clear()
            prefs.edit().putLong("last_reset", now).apply()
        }
    }

    private fun checkForegroundApp() {
        val currentApp = getCurrentForegroundApp()

        if (currentApp != lastForegroundApp) {
            // App switched — accumulate time for previous app
            if (lastForegroundApp != null && sessionStart > 0) {
                val elapsed = System.currentTimeMillis() - sessionStart
                usageMap[lastForegroundApp!!] = (usageMap[lastForegroundApp!!] ?: 0L) + elapsed
            }
            lastForegroundApp = currentApp
            sessionStart = System.currentTimeMillis()
        } else if (currentApp != null && sessionStart > 0) {
            // Same app still in foreground — accumulate
            val elapsed = System.currentTimeMillis() - sessionStart
            usageMap[currentApp] = (usageMap[currentApp] ?: 0L) + elapsed
            sessionStart = System.currentTimeMillis()
        }

        // Check if current app has hit threshold
        val thresholdMs = getThresholdMs()
        if (currentApp != null && currentApp in targetApps) {
            val total = usageMap[currentApp] ?: 0L
            if (total >= thresholdMs && currentApp !in roastedApps) {
                triggerRoast(currentApp, total)
                roastedApps.add(currentApp)
            }
        }
    }

    private fun getCurrentForegroundApp(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 10_000L, time
        )
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
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

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }
}
