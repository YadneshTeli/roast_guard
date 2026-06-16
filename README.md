# 🔥 Doom Roast

**The app that roasts you for doomscrolling.**

Doom Roast monitors your screen time on social media apps and delivers brutally honest roast overlays when you exceed your time limit. It's the productivity app you didn't ask for, but desperately need.

---

## ✨ Features

- **📊 Usage Tracking** — Select and monitor **any** installed application on your device (with dynamic branding fallbacks, deterministic theme generation, and preset icon matching)
- **🪟 Full-Screen Roast Overlay** — Covers the offending app with a savage roast message and a mandatory 10-second shame timer, now using a scrollable viewport to prevent layout clipping
- **🎨 Pure Material 3** — Redesigned interface following strict Material Design 3 guidelines using harmonious container colors, standard surfaces, and official typography
- **🔥 Pre-Written Roast Bank** — 30+ hand-crafted, app-specific roasts that hit different
- **⚡ Roast Intensity** — Choose between Gentle Nudge 😊, Moderate Shame 😤, or Full Intervention 🔥
- **⏱️ Configurable Spam Threshold** — Set your limit from 1 to 120 minutes on the dashboard, with support for per-app thresholds
- **🔄 Aggressive Background Monitoring** — Foreground service polls every 15 seconds. If you exceed your limit, the overlay will continuously spam you every 15 seconds until you close the doomscrolling app!
- **⏸️ Productivity Pause** — One-tap toggle to temporarily pause monitoring when you actually need to use a tracked app for work
- **🚀 Boot Persistence** — Automatically restarts monitoring when your device reboots
- **🌑 Dark Mode UI** — Premium dark interface with Material 3 color harmonies and smooth micro-interactions

---

## 📱 Screenshots

> Coming soon — run the app on an Android device to see the UI!

---

## 🏗️ Architecture

```
roast_guard/
├── android/app/src/main/
│   ├── kotlin/com/example/roast_guard/
│   │   ├── MainActivity.kt            # MethodChannel wiring
│   │   ├── UsageStatsPlugin.kt         # Native usage stats bridge
│   │   ├── ForegroundMonitorService.kt # Background polling service
│   │   ├── OverlayService.kt           # Full-screen roast overlay
│   │   └── BootReceiver.kt             # Auto-restart on reboot
│   └── res/layout/
│       └── overlay_layout.xml          # Native overlay UI
├── lib/
│   ├── main.dart                       # App entry + routing
│   ├── core/
│   │   ├── constants/app_packages.dart # Tracked app metadata
│   │   ├── services/
│   │   │   ├── usage_service.dart      # MethodChannel wrapper
│   │   │   ├── roast_engine.dart       # Roast message generator
│   │   │   ├── groq_service.dart       # GROQ API + SharedPreferences cache
│   │   │   └── background_prefetch.dart# WorkManager callback dispatcher
│   │   └── utils/duration_formatter.dart
│   ├── features/
│   │   ├── onboarding/permission_screen.dart
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── widgets/
│   │   │       ├── app_usage_card.dart
│   │   │       └── roast_intensity_slider.dart
│   │   └── settings/settings_screen.dart
│   └── providers/
│       ├── usage_provider.dart
│       └── config_provider.dart
└── pubspec.yaml
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.38+ |
| State Management | Riverpod 3.x |
| Native Bridge | Kotlin + MethodChannel |
| Background Service | Android Foreground Service + WorkManager |
| Overlay | SYSTEM_ALERT_WINDOW |
| Usage Tracking | Android UsageStatsManager |
| Storage | SharedPreferences |
| Routing | go_router |

---

## 📋 Android Permissions

| Permission | Purpose |
|-----------|---------|
| `PACKAGE_USAGE_STATS` | Read app usage time |
| `SYSTEM_ALERT_WINDOW` | Draw overlay over other apps |
| `FOREGROUND_SERVICE` | Keep monitoring running in background |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Required for specialUse service type |
| `RECEIVE_BOOT_COMPLETED` | Restart service on reboot |
| `POST_NOTIFICATIONS` | Show monitoring notification |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ensure background WorkManager reliability |
| `QUERY_ALL_PACKAGES` | Allows querying and filtering user-installed applications (Android 11+) |

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.38+ (stable channel)
- Android SDK 21+
- Android device or emulator

### Setup

```bash
# Clone the repo
git clone https://github.com/YadneshTeli/roast_guard.git
cd roast_guard

# Install dependencies
flutter pub get

# Run on Android device/emulator
flutter run
```

### First Launch

1. Grant **Usage Access** permission (redirects to Android Settings)
2. Grant **Display Over Apps** permission
3. Grant **Background Activity** permission (Battery Optimization bypass)
4. Tap **"Start Roasting Me"**
5. Open Instagram and wait... 🔥

---

## ⚠️ Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Full support |
| iOS | ❌ Not supported (Apple restricts app usage tracking and overlays) |
| Web/Desktop | ❌ Not applicable |

---

## 🗺️ Roadmap

- [x] **AI Roasts** — Dynamic roasts via GROQ API based on usage patterns
- [x] **Weekly Shame Report** — Beautiful shareable summary card
- [x] **Streak System** — Track days under your limits
- [ ] **Friend Roasting** — Share stats and let friends add custom roasts
- [x] **Per-App Thresholds** — Different limits for different apps
- [ ] **iOS Version** — Screen Time extension (limited)

---

## 📄 License

This project is licensed under the MIT License.

---

<p align="center">
  <b>Stop scrolling. Start living.</b><br>
  <i>— Doom Roast 🔥</i>
</p>
