---
summary: "Krill provider data sources: WebView JWT login, wallet, credits, request stats, and active subscription quota."
read_when:
  - Debugging Krill usage/status parsing
  - Updating Krill login flow or JWT handling
  - Adjusting Krill cost usage scanning
  - Documenting Krill provider behavior
---

# Krill provider

Krill is a multi-model AI API gateway. TokenBar supports native Krill login, wallet/credits display,
request stats, and cost usage through Krill's own API.

## Data sources

All Krill data goes through `https://www.krill-ai.com/api/`. Authentication uses a JWT
obtained via WebView login and stored in the macOS Keychain.

### Auth & login

- **WebView JWT login** — one-time interactive login via Krill's website.
- **JWT stored securely** in macOS Keychain (service `com.tokenbar.krill-jwt`).
- **Auto-refresh** on expiry, with silent re-login when possible.

### Wallet & credits

- `POST /api/request-logs/stats` — aggregate request stats (total requests, tokens, cost).
- `POST /api/request-logs/quota-summary` — plan credits breakdown:
  - `total_plan_cost_usd` / `total_credit_cost_usd`
  - `same_day_quota_charged_usd` / `carryover_quota_charged_usd`
  - `quota_breakdown[]` per-plan detail
- Wallet balance (USD) and Elite Credits progress bar derived from quota-summary.
- 尊享月卡 monthly request quota tracking.

### Cost usage

- `POST /api/request-logs/stats` with 30-day + today windows (2 requests).
- Returns aggregate cost, tokens, requests, and a trend array.
- The trend data powers the Cost history chart in the menu.
- Does **not** scan full request logs — uses stats aggregation to avoid hitting 429 rate limits.

### Active subscription quota

- `GET /api/subscription/daily-quota/active` — daily quota consumption per active subscription.
- Returns `subscriptions[]` with `plan_name` and daily `items[]` (date, `daily_limit_usd`, `used_usd`).
- This is the data behind the Krill website's "活跃订阅每日消耗" chart.
- Currently exposed via CLI but not yet in the menu bar UI (tracked for enhancement).

## Usage details

- The menu card shows wallet balance, Elite Credits progress, and 尊享月卡 request count.
- Cost section shows 30-day total, today's spend, and a history chart.
- Login flow: click "Login" in Settings → Krill → opens WebView → user signs in on Krill's site → JWT captured and stored.
- When JWT expires, the provider auto-refreshes (may require re-login if refresh token is also expired).
- No environment variable or manual API key input needed — everything goes through WebView login.

## Key files

- `Sources/TokenBarCore/Providers/Krill/KrillProviderDescriptor.swift` (descriptor + fetch pipeline)
- `Sources/TokenBarCore/Providers/Krill/KrillUsageFetcher.swift` (wallet/credits/requests fetcher)
- `Sources/TokenBarCore/Providers/Krill/KrillCostUsageFetcher.swift` (cost usage via stats API)
- `Sources/TokenBarCore/Providers/Krill/KrillAPI.swift` (HTTP client + endpoint routing)
- `Sources/TokenBarCore/Providers/Krill/KrillModels.swift` (response models)
- `Sources/TokenBarCore/Providers/Krill/KrillJWTManager.swift` (Keychain JWT store/refresh)
- `Sources/TokenBar/Providers/Krill/KrillProviderImplementation.swift` (settings + login UI)
