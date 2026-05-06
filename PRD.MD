Love this idea — a brutally honest productivity shamer. Here's a full breakdown of how to build this in Flutter:

---

## 🔥 RoastGuard — Architecture Overview

### The Core Problem: Platform Constraints

**Android** → Fully doable. You can track app usage via `UsageStatsManager` and draw overlays via `SYSTEM_ALERT_WINDOW`.

**iOS** → Apple is strict. You **cannot** track other apps' usage or draw overlays over them. The best you can do is Screen Time API (via a Screen Time extension, Apple's own framework) — but it's very limited and requires a special entitlement. **Realistically, this is an Android-first app.**

---

## Android Implementation Plan

### 1. Permissions You Need

```
PACKAGE_USAGE_STATS       → read app usage time
SYSTEM_ALERT_WINDOW       → draw overlay over other apps
FOREGROUND_SERVICE        → keep monitoring running in background
RECEIVE_BOOT_COMPLETED    → restart service on reboot
```

Both `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` require the user to manually grant them in Settings — you'll need to deep-link them there.

---

### 2. App Usage Tracking

Flutter can't do this natively, so you write a **Android native plugin** (Kotlin) using `UsageStatsManager`:

```kotlin
// In your MethodChannel handler (Kotlin)
val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
val endTime = System.currentTimeMillis()
val startTime = endTime - 1000 * 60 * 60 // last 1 hour

val stats = usageStatsManager.queryUsageStats(
    UsageStatsManager.INTERVAL_DAILY, startTime, endTime
)

// Filter for target apps
val targets = listOf("com.instagram.android", "com.twitter.android", "com.facebook.katana")
val result = stats.filter { it.packageName in targets }
    .map { mapOf("package" to it.packageName, "time" to it.totalTimeInForeground) }
```

Call this from Flutter via a `MethodChannel`.

---

### 3. Background Monitoring Service

You need a **foreground service** that polls every 30–60 seconds to check what app is currently in the foreground:

```kotlin
// Detect currently active app
fun getForegroundApp(context: Context): String? {
    val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val time = System.currentTimeMillis()
    val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 10, time)
    return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
}
```

Use the `flutter_foreground_task` package to manage this from Flutter side.

---

### 4. The Overlay System

When the threshold is hit (e.g., 10 mins on Instagram), launch an overlay using `SYSTEM_ALERT_WINDOW`:

```kotlin
val params = WindowManager.LayoutParams(
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
    PixelFormat.TRANSLUCENT
)
windowManager.addView(overlayView, params)
```

The overlay view itself can be a Flutter widget rendered via a **FlutterEngine** in headless mode, or a simple native Android View with text + buttons.

---

### 5. Roast Engine (Flutter Side)

This is the fun part. Build a roast engine in Dart:

```dart
class RoastEngine {
  static const roasts = {
    'com.instagram.android': [
      "You've been on Instagram for {time}. The algorithm is winning. You are losing.",
      "Congrats, you've spent {time} looking at people who are actually doing things.",
      "Instagram called. Even they think you need to touch grass.",
    ],
    'com.twitter.android': [
      "{time} on Twitter. You haven't changed a single mind. Log off.",
      "Breaking: Local person wastes {time} arguing with strangers online.",
    ],
    'com.facebook.katana': [
      "{time} on Facebook. Are you okay? Do you need help?",
      "You've been on Facebook for {time}. Your parents are literally the target audience.",
    ],
  };

  static String getRoast(String package, Duration time) {
    final list = roasts[package] ?? ["Put your phone down. Seriously."];
    final roast = list[Random().nextInt(list.length)];
    return roast.replaceAll('{time}', _formatTime(time));
  }
}
```

Optionally, pipe this through **Gemini API** for dynamic AI-generated roasts based on the user's usage pattern.

---

## Flutter Package Stack

| Purpose | Package |
|---|---|
| Background service | `flutter_foreground_task` |
| Notifications | `flutter_local_notifications` |
| Native channels | Built-in `MethodChannel` |
| State management | Riverpod |
| Storage (thresholds, stats) | `shared_preferences` or Hive |
| AI roasts (optional) | `google_generative_ai` (Gemini) |

---

## Overlay UX — Three Modes

**1. Floating Bubble** — Always visible, shows a timer. Tap to expand roast.

**2. Popup Notification** — System notification with roast text. Less intrusive.

**3. Full-Screen Takeover** — Nuclear option. Covers the app entirely with the roast + a "Okay I'll stop" button + shame timer before dismiss is allowed (e.g., force them to wait 5 seconds).

You can let users pick their "roast intensity" in settings — from *Gentle Nudge* to *Full Intervention*.

---

## iOS Reality Check

For iOS, your only real option is building a **Screen Time Extension** (using `ManagedSettings` + `FamilyControls` frameworks) — which requires a special Apple entitlement that's typically only granted to parental control apps. You could ship the iOS version as a **manual log + notification reminder** app instead, and be upfront about it.

---

## Suggested MVP Scope

1. ✅ Android only
2. ✅ Track Instagram, Twitter, Facebook, YouTube
3. ✅ Configurable thresholds per app (default: 10 min)
4. ✅ Full-screen roast overlay with dismiss timer
5. ✅ Pre-written roast bank (no AI needed for v1)
6. ⬜ AI roasts via Gemini — v2 feature

Want me to scaffold the full project structure, write the Kotlin plugin, or start with the Flutter UI?

Let me generate the full project scaffold. This will cover the Kotlin native plugin, Flutter UI, and the background service wiring.

---

## 📁 Project Structure

```
roastguard/
├── android/
│   └── app/src/main/
│       ├── kotlin/com/roastguard/
│       │   ├── MainActivity.kt
│       │   ├── UsageStatsPlugin.kt
│       │   ├── OverlayService.kt
│       │   ├── ForegroundMonitorService.kt
│       │   └── BootReceiver.kt
│       ├── res/
│       │   └── layout/
│       │       └── overlay_layout.xml
│       └── AndroidManifest.xml
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_packages.dart
│   │   │   └── roast_bank.dart
│   │   ├── services/
│   │   │   ├── usage_service.dart
│   │   │   ├── overlay_service.dart
│   │   │   └── roast_engine.dart
│   │   └── utils/
│   │       └── duration_formatter.dart
│   ├── features/
│   │   ├── onboarding/
│   │   │   └── permission_screen.dart
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── widgets/
│   │   │       ├── app_usage_card.dart
│   │   │       └── roast_intensity_slider.dart
│   │   ├── settings/
│   │   │   └── settings_screen.dart
│   │   └── overlay/
│   │       └── roast_overlay_screen.dart
│   ├── models/
│   │   ├── app_usage.dart
│   │   └── roast_config.dart
│   └── providers/
│       ├── usage_provider.dart
│       ├── config_provider.dart
│       └── roast_provider.dart
├── pubspec.yaml
└── README.md
```

---

## `pubspec.yaml`

```yaml
name: roastguard
description: The app that roasts you for doomscrolling.

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  flutter_foreground_task: ^8.0.0
  flutter_local_notifications: ^17.0.0
  shared_preferences: ^2.2.3
  go_router: ^13.2.0
  google_generative_ai: ^0.4.0   # optional, for AI roasts
  hive_flutter: ^1.1.0
  freezed_annotation: ^2.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.9
  freezed: ^2.5.2
```

---

## Android — `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>
        <activity android:name=".MainActivity" ... />

        <!-- Foreground Monitor Service -->
        <service
            android:name=".ForegroundMonitorService"
            android:foregroundServiceType="specialUse"
            android:exported="false" />

        <!-- Overlay Service -->
        <service
            android:name=".OverlayService"
            android:exported="false" />

        <!-- Boot Receiver -->
        <receiver
            android:name=".BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

---

## Kotlin — `UsageStatsPlugin.kt`

```kotlin
package com.roastguard

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
            "getUsageStats" -> getUsageStats(call, result)
            "getForegroundApp" -> result.success(getForegroundApp())
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

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

        val result_list = stats
            ?.filter { it.totalTimeInForeground > 0 }
            ?.map {
                mapOf(
                    "packageName" to it.packageName,
                    "totalTimeMs" to it.totalTimeInForeground,
                    "lastTimeUsed" to it.lastTimeUsed
                )
            } ?: emptyList()

        result.success(result_list)
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
}
```

---

## Kotlin — `ForegroundMonitorService.kt`

```kotlin
package com.roastguard

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class ForegroundMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val pollInterval = 30_000L // 30 seconds
    private val usageMap = mutableMapOf<String, Long>() // packageName -> accumulated ms

    // Configurable thresholds (default 10 min per app)
    private val thresholdMs = 10 * 60 * 1000L

    private val targetApps = setOf(
        "com.instagram.android",
        "com.twitter.android",
        "com.facebook.katana",
        "com.google.android.youtube",
        "com.zhiliaoapp.musically" // TikTok
    )

    private var lastForegroundApp: String? = null
    private var sessionStart: Long = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, pollInterval)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, buildNotification())
        handler.post(pollRunnable)
        return START_STICKY
    }

    private fun checkForegroundApp() {
        val plugin = UsageStatsPlugin(this)
        // Use reflection trick or pass context directly
        val currentApp = getCurrentForegroundApp()

        if (currentApp != lastForegroundApp) {
            // App switched — accumulate time for previous app
            if (lastForegroundApp != null && sessionStart > 0) {
                val elapsed = System.currentTimeMillis() - sessionStart
                usageMap[lastForegroundApp!!] = (usageMap[lastForegroundApp!!] ?: 0L) + elapsed
            }
            lastForegroundApp = currentApp
            sessionStart = System.currentTimeMillis()
        }

        // Check if current app has hit threshold
        if (currentApp != null && currentApp in targetApps) {
            val total = usageMap[currentApp] ?: 0L
            if (total >= thresholdMs) {
                triggerRoast(currentApp, total)
                usageMap[currentApp] = 0L // reset after roast
            }
        }
    }

    private fun getCurrentForegroundApp(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            android.app.usage.UsageStatsManager.INTERVAL_DAILY,
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

    private fun buildNotification(): Notification {
        val channelId = "roastguard_monitor"
        val channel = NotificationChannel(
            channelId, "RoastGuard Monitor",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("RoastGuard is watching 👀")
            .setContentText("Monitoring your scroll habits...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }
}
```

---

## Kotlin — `OverlayService.kt`

```kotlin
package com.roastguard

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.*
import android.widget.*
import androidx.cardview.widget.CardView

class OverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra("package_name") ?: return START_NOT_STICKY
        val totalMs = intent.getLongExtra("total_ms", 0L)

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

        // Pass package + time to Flutter roast engine via shared prefs or direct string
        roastText?.text = getRoastForPackage(packageName, totalMs)

        // Force 5-second wait before dismiss
        var secondsLeft = 5
        timerText?.text = "You must face this for ${secondsLeft}s"
        dismissBtn?.isEnabled = false

        val timerRunnable = object : Runnable {
            override fun run() {
                secondsLeft--
                if (secondsLeft <= 0) {
                    timerText?.text = "Fine. Go touch grass."
                    dismissBtn?.isEnabled = true
                } else {
                    timerText?.text = "You must face this for ${secondsLeft}s"
                    overlayView?.postDelayed(this, 1000)
                }
            }
        }
        overlayView?.postDelayed(timerRunnable, 1000)

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
                "Instagram called. Even they think you need to touch grass."
            ),
            "com.twitter.android" to listOf(
                "$minutes mins on Twitter. You haven't changed a single mind. Log off.",
                "Breaking: Local person wastes $minutes mins arguing with strangers online."
            ),
            "com.facebook.katana" to listOf(
                "$minutes mins on Facebook. Are you okay?",
                "You've been on Facebook for $minutes mins. Your parents are literally the target audience."
            ),
            "com.google.android.youtube" to listOf(
                "$minutes mins on YouTube. You started with one video. Classic.",
                "The recommended algorithm has claimed another $minutes mins of your life."
            )
        )
        val list = roasts[packageName] ?: listOf("$minutes mins of your life. Gone. Forever.")
        return list.random()
    }

    private fun removeOverlay() {
        overlayView?.let { windowManager?.removeView(it) }
        overlayView = null
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

---

## Android — `overlay_layout.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#CC000000">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:orientation="vertical"
        android:padding="32dp">

        <TextView
            android:id="@+id/roast_emoji"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_gravity="center"
            android:text="🔥"
            android:textSize="64sp" />

        <TextView
            android:id="@+id/roast_text"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="24dp"
            android:gravity="center"
            android:textColor="#FFFFFF"
            android:textSize="22sp"
            android:textStyle="bold"
            android:lineSpacingExtra="4dp" />

        <TextView
            android:id="@+id/timer_text"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="16dp"
            android:gravity="center"
            android:textColor="#FFAA00"
            android:textSize="14sp" />

        <Button
            android:id="@+id/dismiss_btn"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_gravity="center"
            android:layout_marginTop="32dp"
            android:text="Ok fine, I'll be productive"
            android:backgroundTint="#FF4444"
            android:textColor="#FFFFFF"
            android:paddingHorizontal="24dp"
            android:paddingVertical="12dp" />

    </LinearLayout>
</FrameLayout>
```

---

## Kotlin — `BootReceiver.kt`

```kotlin
package com.roastguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val serviceIntent = Intent(context, ForegroundMonitorService::class.java)
            context.startForegroundService(serviceIntent)
        }
    }
}
```

---

## Flutter — `core/constants/app_packages.dart`

```dart
class AppPackages {
  static const Map<String, AppMeta> targets = {
    'com.instagram.android': AppMeta(name: 'Instagram', emoji: '📸'),
    'com.twitter.android': AppMeta(name: 'Twitter/X', emoji: '🐦'),
    'com.facebook.katana': AppMeta(name: 'Facebook', emoji: '👴'),
    'com.google.android.youtube': AppMeta(name: 'YouTube', emoji: '📺'),
    'com.zhiliaoapp.musically': AppMeta(name: 'TikTok', emoji: '🎵'),
    'com.reddit.frontpage': AppMeta(name: 'Reddit', emoji: '👽'),
  };
}

class AppMeta {
  final String name;
  final String emoji;
  const AppMeta({required this.name, required this.emoji});
}
```

---

## Flutter — `core/services/usage_service.dart`

```dart
import 'package:flutter/services.dart';

class UsageService {
  static const _channel = MethodChannel('com.roastguard/usage_stats');

  Future<bool> hasUsagePermission() async {
    return await _channel.invokeMethod('hasUsagePermission') ?? false;
  }

  Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod('hasOverlayPermission') ?? false;
  }

  Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  Future<List<AppUsageStat>> getUsageStats({int hours = 24}) async {
    final raw = await _channel.invokeListMethod<Map>('getUsageStats', {'hours': hours});
    return raw?.map((e) => AppUsageStat.fromMap(Map<String, dynamic>.from(e))).toList() ?? [];
  }

  Future<void> startMonitorService() async {
    await _channel.invokeMethod('startMonitorService');
  }
}

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
      packageName: map['packageName'],
      totalTime: Duration(milliseconds: map['totalTimeMs']),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(map['lastTimeUsed']),
    );
  }
}
```

---

## Flutter — `core/services/roast_engine.dart`

```dart
import 'dart:math';

class RoastEngine {
  static final _random = Random();

  static const _roasts = <String, List<String>>{
    'com.instagram.android': [
      "You've been on Instagram for {time}. The algorithm is winning. You are losing.",
      "Congrats, {time} watching people who are actually doing things.",
      "Instagram called. Even they think you need to touch grass.",
      "{time} of reels. Zero reels of your own life recorded.",
      "You've scrolled {time} worth of content. Your dreams are still loading.",
    ],
    'com.twitter.android': [
      "{time} on Twitter. You haven't changed a single mind. Log off.",
      "Breaking: Local person wastes {time} arguing with strangers online.",
      "{time} of hot takes. None of them were yours.",
      "You spent {time} on Twitter. The timeline is fine. Your productivity is not.",
    ],
    'com.facebook.katana': [
      "{time} on Facebook. Are you okay? Do you need help?",
      "You've been on Facebook for {time}. Your parents are literally the target audience.",
      "{time} of Facebook. You are becoming your parents. This is not a compliment.",
    ],
    'com.google.android.youtube': [
      "{time} on YouTube. You started with one video. Classic.",
      "The recommended algorithm has claimed another {time} of your life.",
      "{time} of YouTube. You could have built something. Instead you watched someone else build.",
      "You've watched {time} of content. Your own channel still has 0 videos.",
    ],
    'com.zhiliaoapp.musically': [
      "{time} on TikTok. Your attention span is now 3 seconds. Congratulations.",
      "You've lost {time} to 15-second videos. Do the math. That's a lot of videos.",
    ],
    'com.reddit.frontpage': [
      "{time} on Reddit. You've learned a lot about things that don't matter.",
      "You spent {time} on Reddit. AMA: How does it feel to waste your potential?",
    ],
  };

  static const _genericRoasts = [
    "Put your phone down. Whatever you're looking for isn't in there.",
    "{time} of your finite life. Gone.",
    "Your future self is cringing at you right now.",
    "Get a job. Or at least pretend to.",
    "{time} scrolled. Zero progress made. You're built different (not in a good way).",
  ];

  static String getRoast(String packageName, Duration time) {
    final timeStr = _formatDuration(time);
    final list = _roasts[packageName] ?? _genericRoasts;
    final roast = list[_random.nextInt(list.length)];
    return roast.replaceAll('{time}', timeStr);
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}
```

---

## Flutter — `features/onboarding/permission_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/usage_service.dart';
import '../../providers/config_provider.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  final _usageService = UsageService();
  bool _hasUsage = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final usage = await _usageService.hasUsagePermission();
    final overlay = await _usageService.hasOverlayPermission();
    setState(() {
      _hasUsage = usage;
      _hasOverlay = overlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text('🔥', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'RoastGuard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need two permissions to roast you properly.',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 48),
              _PermissionTile(
                icon: '📊',
                title: 'Usage Access',
                subtitle: 'So we know how long you\'ve been doomscrolling',
                granted: _hasUsage,
                onTap: () async {
                  await _usageService.requestUsagePermission();
                  await Future.delayed(const Duration(seconds: 1));
                  _checkPermissions();
                },
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: '🪟',
                title: 'Display Over Apps',
                subtitle: 'So we can interrupt your scrolling with shame',
                granted: _hasOverlay,
                onTap: () async {
                  await _usageService.requestOverlayPermission();
                  await Future.delayed(const Duration(seconds: 1));
                  _checkPermissions();
                },
              ),
              const Spacer(),
              if (_hasUsage && _hasOverlay)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _usageService.startMonitorService();
                      // Navigate to dashboard
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Roasting Me',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String icon, title, subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted ? Colors.green : Colors.grey[800]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            Icon(
              granted ? Icons.check_circle : Icons.arrow_forward_ios,
              color: granted ? Colors.green : Colors.grey,
              size: 20,
            )
          ],
        ),
      ),
    );
  }
}
```

---

## Flutter — `features/dashboard/dashboard_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/usage_provider.dart';
import '../../core/constants/app_packages.dart';
import 'widgets/app_usage_card.dart';
import 'widgets/roast_intensity_slider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('🔥 RoastGuard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {/* Navigate to settings */},
          )
        ],
      ),
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        data: (stats) {
          final filtered = stats
              .where((s) => AppPackages.targets.containsKey(s.packageName))
              .toList()
            ..sort((a, b) => b.totalTime.compareTo(a.totalTime));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Shame summary
              _ShameSummary(stats: filtered),
              const SizedBox(height: 24),
              const Text('Today\'s Damage',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...filtered.map((s) => AppUsageCard(stat: s)),
              const SizedBox(height: 24),
              const RoastIntensitySlider(),
            ],
          );
        },
      ),
    );
  }
}

class _ShameSummary extends StatelessWidget {
  final List<dynamic> stats;
  const _ShameSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalMs = stats.fold<int>(
        0, (sum, s) => sum + s.totalTime.inMilliseconds);
    final total = Duration(milliseconds: totalMs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today you wasted', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            '${total.inHours}h ${total.inMinutes.remainder(60)}m',
            style: const TextStyle(
                color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const Text('on apps that bring you no joy or income.',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}
```

---

## Flutter — `providers/usage_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/usage_service.dart';

final usageServiceProvider = Provider((_) => UsageService());

final usageStatsProvider = FutureProvider<List<AppUsageStat>>((ref) async {
  final service = ref.read(usageServiceProvider);
  return service.getUsageStats(hours: 24);
});
```

---

## What's Next (v2 Ideas)

- **AI Roasts** — Send `packageName + duration` to Gemini, get a dynamically personalized roast
- **Weekly Shame Report** — A beautifully designed summary card (shareable)
- **Streak system** — Days where you stayed under your limits
- **Friend roasting** — Share your stats publicly and let friends add custom roasts
- **iOS version** — Screen Time extension with limited but real tracking

---

Want me to add the `MainActivity.kt` wiring, the `RoastIntensitySlider` widget, the settings screen with per-app thresholds, or the Gemini AI roast integration next?
