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

        // Prefer a roast pre-fetched by the Dart side (via GROQ); fall back to static.
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val pendingRoast = flutterPrefs.getString("flutter.pending_roast", null)
        roastText?.text = if (!pendingRoast.isNullOrBlank()) {
            // Clear so the same roast isn't shown twice
            flutterPrefs.edit().remove("flutter.pending_roast").apply()
            pendingRoast
        } else {
            getRoastForPackage(packageName, totalMs)
        }

        // Force random wait between 10 and 60 seconds before dismiss
        var secondsLeft = (10..60).random()
        timerText?.text = "You must face this for ${secondsLeft}s"
        dismissBtn?.isEnabled = false
        dismissBtn?.alpha = 0.4f

        val runnable = object : Runnable {
            override fun run() {
                // Guard: view may have been removed already
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

        dismissBtn?.setOnClickListener { removeOverlay() }

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
        val roasts = mapOf(
            "com.instagram.android" to listOf(
                "You've been on Instagram for $minutes mins. The algorithm is winning. You are losing.",
                "Congrats, $minutes mins watching people who are actually doing things.",
                "Instagram called. Even they think you need to touch grass.",
                "$minutes mins of reels. Zero reels of your own life recorded."
            ),
            "com.twitter.android" to listOf(
                "$minutes mins on Twitter. You haven't changed a single mind. Log off.",
                "Breaking: Local person wastes $minutes mins arguing with strangers online.",
                "$minutes mins of hot takes. None of them were yours."
            ),
            "com.facebook.katana" to listOf(
                "$minutes mins on Facebook. Are you okay?",
                "You've been on Facebook for $minutes mins. Your parents are literally the target audience.",
                "$minutes mins of Facebook. You are becoming your parents. This is not a compliment."
            ),
            "com.google.android.youtube" to listOf(
                "$minutes mins on YouTube. You started with one video. Classic.",
                "The recommended algorithm has claimed another $minutes mins of your life.",
                "$minutes mins of YouTube. You could have built something. Instead you watched someone else build."
            ),
            "com.zhiliaoapp.musically" to listOf(
                "$minutes mins on TikTok. Your attention span is now 3 seconds. Congratulations.",
                "You've lost $minutes mins to 15-second videos. Do the math. That's a lot of videos."
            ),
            "com.reddit.frontpage" to listOf(
                "$minutes mins on Reddit. You've learned a lot about things that don't matter.",
                "You spent $minutes mins on Reddit. AMA: How does it feel to waste your potential?"
            ),
            "com.snapchat.android" to listOf(
                "$minutes mins on Snapchat. Those streaks won't help your resume.",
                "You spent $minutes mins sending disappearing messages. Much like your productivity."
            )
        )
        val list = roasts[packageName] ?: listOf("$minutes mins of your life. Gone. Forever.")
        return list.random()
    }

    private fun removeOverlay() {
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
            .putLong("next_allowed_roast_time", nextAllowedTime)
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
