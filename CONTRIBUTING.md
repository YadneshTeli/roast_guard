# Contributing to RoastGuard (Doom Roast)

Thanks for your interest in contributing to **RoastGuard**! Whether you are fixing an Android service bug, improving the Material 3 UI, tuning AI roast sanitizers, or updating documentation, your help is welcome.

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) and [Security Policy](SECURITY.md) before participating.

---

## Prerequisites

- **Flutter SDK**: `3.38+` (`3.38.6` on the `stable` channel is used in CI)
- **Dart SDK**: `^3.10.7`
- **Java**: JDK `17` (configured in `android/app/build.gradle.kts`)
- **Android**: Android SDK `21+` (`min_sdk_android: 21`) and a physical Android device or emulator
  > **Note:** Core features (`UsageStatsManager` tracking and `SYSTEM_ALERT_WINDOW` overlays) are Android-native and cannot be tested on iOS, Web, or Desktop.

---

## Local Development Setup

1. **Fork & clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/roast_guard.git
   cd roast_guard
   ```

2. **Create your `.env` file** from the example template:
   ```bash
   cp .env.example .env
   ```
   > **Important:** `pubspec.yaml` bundles `.env` as a Flutter asset and `lib/main.dart` loads it on startup via `dotenv.load(fileName: '.env')`. You **must** have a `.env` file present locally to run or build the app.
   >
   > - Optionally add `GEMINI_API_KEY` (Google Gemma 4 via Gemini API) and/or `GROQ_API` (Groq fallback) in `.env`.
   > - If you leave placeholder or empty values, the app still runs and falls back to the offline roast bank in `RoastAiService`.
   > - **Never commit `.env`** or paste API keys into issues, PRs, or logs.

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the app on an Android device or emulator**:
   ```bash
   flutter run
   ```

5. **Grant required Android permissions on first launch**:
   - **Usage Access** (`PACKAGE_USAGE_STATS`)
   - **Display Over Other Apps** (`SYSTEM_ALERT_WINDOW`)
   - **Background Activity** (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)

---

## Repository Structure

```text
roast_guard/
├── .github/
│   ├── ISSUE_TEMPLATE/             # Bug report & feature request forms
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
│       ├── ci.yml                  # PR/push lint & test checks
│       └── release.yml             # Tag-based APK/AAB release build
├── android/app/src/main/
│   ├── kotlin/com/example/roast_guard/
│   │   ├── MainActivity.kt             # Flutter engine & MethodChannel bridge
│   │   ├── UsageStatsPlugin.kt         # UsageStatsManager & app list bridge
│   │   ├── ForegroundMonitorService.kt # Background foreground polling service
│   │   ├── OverlayService.kt           # SYSTEM_ALERT_WINDOW roast overlay
│   │   └── BootReceiver.kt             # Auto-restart monitor on boot
│   └── res/layout/overlay_layout.xml   # Native overlay layout
├── lib/
│   ├── main.dart                   # Entry point, routing, WorkManager & lifecycle
│   ├── core/
│   │   ├── constants/              # App package metadata & defaults
│   │   ├── services/               # RoastAiService, GemmaService, GroqService, UsageService, etc.
│   │   └── utils/                  # Formatters & helpers
│   ├── features/                   # onboarding, dashboard, settings, reports
│   └── providers/                  # Riverpod 3.x state notifiers & providers
├── test/                           # Dart/Flutter unit & widget tests
└── website/                        # Static landing page (Netlify)
```

---

## Coding & Architecture Guidelines

- **Linting**: Follow the rules in `analysis_options.yaml` (`package:flutter_lints/flutter.yaml`). `flutter analyze` must pass with **0 issues**.
- **State Management**: Use Riverpod 3.x patterns consistent with existing providers under `lib/providers/` and view models under `lib/features/*/view_models/`.
- **Material 3 UI**: Keep UI components aligned with Material Design 3 theme tokens (`Theme.of(context).colorScheme`).
- **AI Output Sanitization**: Any changes to prompts, `GemmaService`, `GroqService`, or `RoastAiService` must preserve `<think>...</think>` and reasoning-scratchpad stripping (`RoastAiService.cleanRoast` and native filtering in `OverlayService.kt`).
- **Secrets & Storage**: API keys are read strictly from `.env` via `flutter_dotenv`. Do **not** persist API keys in `SharedPreferences` or source code.
- **Native Kotlin Changes**: Flutter Hot Reload / Hot Restart only updates Dart code. After modifying files under `android/`, perform a full stop and rebuild (`flutter run`).

---

## Debugging & Testing Tips

- **Previewing the Overlay Instantly**: Use the **Test Overlay Now** button under **Settings → About RoastGuard** to verify `OverlayService` layout and permissions without waiting for usage thresholds.
- **Inspecting Native Monitor Logs**:
  ```bash
  adb logcat -s RoastGuardMonitor OverlayService
  ```
- **Previewing the Website** (if modifying `website/`):
  ```bash
  cd website
  python -m http.server 8000
  ```

---

## Checks Before Opening a Pull Request

Run both checks locally before pushing:

```bash
flutter analyze
flutter test
```

If you changed native Android/Kotlin code or overlay layouts, also verify on an Android emulator or physical device.

---

## Commit & Pull Request Process

1. Create a feature or fix branch from `main` (e.g., `fix/overlay-cooldown` or `feat/new-roast-pack`).
2. Follow [Conventional Commits](https://www.conventionalcommits.org/) style used in this repository:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `style:` for UI/formatting changes
   - `refactor:` for code restructuring without behavior change
   - `docs:` for documentation updates
   - `ci:` / `chore:` for build, tooling, or maintenance changes
3. Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md) clearly, referencing any related issues.
4. Ensure CI passes and no secrets or `.env` files are included in your diff.
