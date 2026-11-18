# Privacy Policy — RoastGuard (Doom Roast)

_Last updated: 2026-11-18_

RoastGuard ("Doom Roast") is an open-source digital wellbeing app designed to keep your personal usage data on your device.

## 1. Data Accessed & How It Is Used

### App Usage Data (`PACKAGE_USAGE_STATS`)
- Accessed through Android's `UsageStatsManager` solely on your device to measure foreground time spent in apps you choose to monitor and to detect when a configured time threshold is exceeded.
- Stored locally on-device in `SharedPreferences` (preferences, thresholds, streaks, and cached roast text).
- RoastGuard has **no analytics SDKs, no advertising trackers, and no RoastGuard backend servers**.

### Installed Applications (`QUERY_ALL_PACKAGES`)
- Used locally in **Settings → Tracked Apps → Manage Apps** to let you pick which installed applications to monitor.
- The list of all installed applications on your device is never uploaded or transmitted off-device.

### Screen Overlay (`SYSTEM_ALERT_WINDOW`)
- Used solely to render the roast alert overlay when a monitored app exceeds your configured time limit.
- RoastGuard does **not** take screenshots, inspect keystrokes, or read screen contents from other applications.

## 2. Third-Party AI Providers (Optional)

When an AI provider key (`GEMINI_API_KEY` for Google Gemma 4 via the Gemini API, or `GROQ_API` for Groq) is configured at build time in `.env`:

- To generate a roast or weekly summary, RoastGuard sends only:
  - The display name of the monitored app (for example, `Instagram`)
  - Duration spent (for example, `25m`)
  - Selected roast intensity and general time-of-day context (for single roasts)
- Requests are sent directly to your configured provider:
  - [Google Gemini API Terms / Privacy](https://ai.google.dev/gemini-api/terms)
  - [Groq Privacy Policy](https://groq.com/privacy-policy/)
- If no API keys are configured, or when offline, RoastGuard falls back to built-in local roasts with zero external API calls.

## 3. Data Retention & Deletion

All preferences, monitored app lists, streaks, and cached roasts live locally in Android app storage (`SharedPreferences`). Clearing app data or uninstalling RoastGuard permanently removes all stored data from your device.

## 4. Contact

If you have privacy questions or concerns, please open an issue at [github.com/YadneshTeli/roast_guard/issues](https://github.com/YadneshTeli/roast_guard/issues) or email **yadnesht909@gmail.com**.
