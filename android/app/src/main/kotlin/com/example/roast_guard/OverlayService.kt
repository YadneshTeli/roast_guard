package com.example.roast_guard

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.*
import android.widget.*

class OverlayService : Service() {

    companion object {
        // Companion-object flag prevents re-entry races:
        // if onStartCommand fires again before Android fully destroys the old
        // instance, windowManager?.addView() would throw BadTokenException.
        @Volatile
        var isShowing: Boolean = false

        // SharedPreferences key Flutter reads on resume to trigger a roast prefetch.
        // Value is the package name that needs a fresh roast cached.
        const val KEY_PREFETCH_PENDING = "flutter.roast_prefetch_pending"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    // Promoted to class fields so removeOverlay() can cancel pending callbacks
    // and prevent updates on detached views (fixes the handler/runnable leak).
    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isShowing) return START_NOT_STICKY

        val packageName = intent?.getStringExtra("package_name") ?: return START_NOT_STICKY
        val totalMs = intent.getLongExtra("total_ms", 0L)

        isShowing = true
        showOverlay(packageName, totalMs)
        return START_NOT_STICKY
    }

    private fun showOverlay(packageName: String, totalMs: Long) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val inflater = LayoutInflater.from(this)
        overlayView = inflater.inflate(R.layout.overlay_layout, null)

        val roastText = overlayView?.findViewById<TextView>(R.id.roast_text)
        val dismissBtn = overlayView?.findViewById<Button>(R.id.dismiss_btn)
        val timerText = overlayView?.findViewById<TextView>(R.id.timer_text)

        // Read the pre-fetched AI roast cached by the Flutter side at startup.
        // Key written by Dart: SharedPreferences.setString('cached_roast_$packageName', ...)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cacheKey = "flutter.cached_roast_$packageName"
        val cachedRoast = flutterPrefs.getString(cacheKey, null)

        roastText?.text = if (!cachedRoast.isNullOrBlank()) {
            // Consume the cached roast so the next overlay gets a fresh one
            flutterPrefs.edit().remove(cacheKey).apply()
            cachedRoast
        } else {
            // Cache miss — use static fallback (happens on first launch or offline)
            getRoastForPackage(packageName, totalMs)
        }

        // Force random wait between 10 and 60 seconds before dismiss
        var secondsLeft = (10..60).random()
        timerText?.text = "You must face this for ${secondsLeft}s"
        dismissBtn?.isEnabled = false
        dismissBtn?.alpha = 0.4f

        val runnable = object : Runnable {
            override fun run() {
                if (overlayView == null) return
                secondsLeft--
                if (secondsLeft <= 0) {
                    timerText?.text = "Fine. Go touch grass."
                    dismissBtn?.isEnabled = true
                    dismissBtn?.alpha = 1.0f
                } else {
                    timerText?.text = "You must face this for ${secondsLeft}s"
                    handler.postDelayed(this, 1000)
                }
            }
        }
        timerRunnable = runnable
        handler.postDelayed(runnable, 1000)

        dismissBtn?.setOnClickListener { removeOverlay(packageName) }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        windowManager?.addView(overlayView, params)
    }

    private fun getRoastForPackage(packageName: String, totalMs: Long): String {
        val minutes = totalMs / 60_000
        return "$minutes mins wasted. Your future self is already disappointed."
    }

    /**
     * Removes the overlay UI and updates the grace period.
     * The prefetch flag was already written by ForegroundMonitorService.triggerRoast()
     * before the overlay started — no need to write it again here.
     */
    private fun removeOverlay(packageName: String) {
        // Cancel pending timer callbacks BEFORE detaching the view
        timerRunnable?.let { handler.removeCallbacks(it) }
        timerRunnable = null

        overlayView?.let { windowManager?.removeView(it) }
        overlayView = null
        isShowing = false

        // Set random grace period between 15s and 5m (300s) before next blast
        val gracePeriodSeconds = (15..300).random()
        val nextAllowedTime = System.currentTimeMillis() + (gracePeriodSeconds * 1000L)
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putLong("flutter.next_allowed_roast_time", nextAllowedTime)
            .apply()

        // Service intentionally kept alive (no stopSelf) to avoid the race where
        // Android starts a new instance before the old one is fully destroyed,
        // which would cause windowManager?.addView() to throw BadTokenException.
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        // Ensure cleanup even if the service is killed externally
        timerRunnable?.let { handler.removeCallbacks(it) }
        overlayView?.let { windowManager?.removeView(it) }
        overlayView = null
        isShowing = false
        super.onDestroy()
    }
}
