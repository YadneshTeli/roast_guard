# Changelog

All notable changes to RoastGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-06

### 🔥 Initial Release — MVP

The first release of RoastGuard. The app that roasts you for doomscrolling.

### Added

- **Android Usage Tracking** — Monitor time spent on 7 social media apps via `UsageStatsManager`
  - Instagram, Twitter/X, Facebook, YouTube, TikTok, Reddit, Snapchat
- **Full-Screen Roast Overlay** — Native Android overlay using `SYSTEM_ALERT_WINDOW` with a 5-second shame timer before dismiss is allowed
- **Background Monitoring Service** — Foreground service that polls every 30 seconds to detect doomscrolling
- **Pre-Written Roast Bank** — 30+ hand-crafted, app-specific roast messages with time-aware formatting
- **Permission Onboarding** — Animated onboarding flow guiding users to grant Usage Access and Display Over Apps permissions
- **Dashboard Screen** — Shows total wasted time, "Roast of the Moment", and per-app usage cards with severity indicators (Chill/Hmm.../Yikes/Bruh)
- **Roast Intensity Selector** — Three levels: Gentle Nudge 😊, Moderate Shame 😤, Full Intervention 🔥
- **Configurable Threshold** — Slider to set time limit from 1 to 120 minutes
- **Boot Persistence** — `BootReceiver` automatically restarts monitoring after device reboot
- **Settings Screen** — Configure threshold, view tracked apps, and app info
- **State Management** — Riverpod 3.x with `Notifier` pattern, persisted via `SharedPreferences`
- **Dark Mode UI** — Premium dark interface with red/orange gradient accents, animated transitions, and micro-interactions

### Technical

- Flutter 3.38+ with Dart 3.10+
- Kotlin native layer with 5 Android components (MainActivity, UsageStatsPlugin, ForegroundMonitorService, OverlayService, BootReceiver)
- Core library desugaring enabled for Java 8+ API support
- Zero analysis warnings (`flutter analyze` clean)
