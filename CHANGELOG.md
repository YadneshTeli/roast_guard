# Changelog

All notable changes to RoastGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [2.1.0] - 2026-06-16

### Added
- **Dynamic App Tracking**: Replaced the hardcoded social media package monitoring list with dynamic queries. Users can now select and monitor *any* installed app on their device.
- **Dynamic App Metadata Fallbacks**: Automatically generates clean icon fallbacks and deterministic branding colors for non-preset monitored applications.
- **M3 Real-Time App Manager**: Added a searchable, scrollable Material 3 Modal Bottom Sheet in the settings page to check, add, and remove monitored packages in real-time.
- **Android 11+ Package Query Permission**: Declared `QUERY_ALL_PACKAGES` permission to ensure visibility of all installed packages under strict Android API 30+ restrictions.

### Changed
- **Pure Material 3 Redesign**: Refactored the onboarding, dashboard, settings, and weekly report views to comply strictly with Material Design 3. Removed custom glows, drop shadows, and linear text gradients in favor of standard M3 card, surface, and typography elements.
- **Streak Badge Theme**: Updated the fire streak badge to use standard M3 `errorContainer` and `onErrorContainer` theme colors for improved contrast.

### Fixed
- **SharedPreferences ClassCastException (Int to Long)**: Handled Flutter-to-Kotlin int-casting quirks on Android by introducing a fallback helper to process `Long` values.
- **JSON List Prefix Parsing**: Fixed background monitor failures by isolating JSON arrays directly using character search, bypassing arbitrary Flutter prefixing.
- **Overlay Layout Scrollable Viewport**: Added a `ScrollView` wrapper inside the native overlay layout to prevent clipping on smaller devices and ensure the dismiss button is always reachable.

---

## [2.0.1] - 2026-05-08

### Changed
- **Zero-Latency AI Overlays**: Completely re-architected the AI pipeline to use a proactive pre-fetch strategy instead of reactive on-resume fetching, guaranteeing AI-generated roasts are ready instantly when the overlay triggers.
- **Battery Optimization Bypass**: Added a "Background Activity" permission tile in the onboarding flow to disable Android battery optimizations, ensuring the background WorkManager task runs reliably.
- **State Management Consistency**: Refactored `RoastGuardApp` to `ConsumerStatefulWidget` to maintain cross-isolate SharedPreferences synchronization and strict Riverpod alignment.

### Fixed
- Resolved cross-process caching staleness by forcing Flutter to reload the underlying `SharedPreferences` disk file upon app resume and background isolate execution.
- Removed redundant state writes in the Kotlin `OverlayService` to establish `ForegroundMonitorService` as the single source of truth for triggering pre-fetches.

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
