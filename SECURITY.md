# Security Policy

## Supported Versions

Only the latest minor release receives security and bug-fix updates.

| Version | Supported |
| ------- | --------- |
| 2.2.x   | ✅ Yes     |
| < 2.2.0 | ❌ No      |

---

## Security & Secret Hygiene

RoastGuard handles sensitive Android permissions (`PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `QUERY_ALL_PACKAGES`) and optional LLM API keys (`GEMINI_API_KEY`, `GROQ_API`):

- **API Keys**: Keys are loaded strictly at runtime from `.env` via `flutter_dotenv` (injected from GitHub Secrets during CI release builds) and are **never** stored in plaintext `SharedPreferences` or committed to source control.
- **On-Device Data**: Screen-time metrics, tracked package selections, thresholds, and streaks remain locally on the user's device.
- **Contributor Reminder**: Do not include `.env` files, personal API keys, or sensitive device logs (`Authorization` / `x-goog-api-key` headers) in issues, screenshots, or pull requests.

---

## Reporting a Vulnerability

If you discover a security vulnerability in RoastGuard, **please do not report it via a public GitHub issue**.

Instead, please report it privately using one of the following methods:

1. **GitHub Private Vulnerability Reporting** (recommended):
   Open an advisory draft at `https://github.com/YadneshTeli/roast_guard/security/advisories/new`.
2. **Email**:
   Send details directly to **yadnesht909@gmail.com** with `[RoastGuard Security]` in the subject line.

### What to Include

- A clear description of the vulnerability and potential impact
- Steps to reproduce or a minimal proof of concept
- Affected app version, Android OS version, or component (Dart, Kotlin native service, CI workflow, or `website/`)

You can expect an initial acknowledgment within **72 hours** and status updates as a fix is prepared. Once resolved, we will coordinate disclosure and credit you if desired.
