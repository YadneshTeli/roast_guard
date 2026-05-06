# Changelog

All notable changes to RoastGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-05-07

### Added
- **Streak System**: Integrated a robust local streak tracking system that rewards consistent usage and punishes failures, with a dashboard badge displaying active streaks.
- **Weekly Shame Report**: A massive new feature that aggregates 7 days of usage data and generates a brutal 3-sentence summary utilizing the Llama-3.3-70b-versatile model via Groq API.
- **Share My Shame**: Added an image-capture boundary feature to let users screenshot their Weekly Report and post it to social media via native sharing dialogs.
- **Custom Thresholds per App**: Added a custom thresholds toggle in the dashboard to set individual time limits per monitored app rather than a global setting.

### Fixed
- Addressed state management synchronization issues across `SharedPreferences` for per-app thresholds by updating to `FutureProvider.family`.

---

## [1.0.2] - 2026-05-06

### Changed
- **Continuous Overlay Spam**: The background service will now continuously show the overlay (every 15 seconds) after the threshold is hit until the targeted app is closed, instead of just once per day.

### Added
- **Configurable Spam Threshold UI**: Added a sleek slider in the dashboard to quickly change the time threshold before the roasting starts.

---

## [1.0.1] - 2026-05-06

### Changed
- **Rebrand to Doom Roast**: Changed app name from RoastGuard to Doom Roast and updated the app icon to a new premium flat vector flame design.
- **Overlay Duration**: Increased the mandatory shame wait timer from 5 seconds to 10 seconds.
- **Active Monitoring Toggle**: Added an in-app toggle on the dashboard to easily pause and resume background monitoring.

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
