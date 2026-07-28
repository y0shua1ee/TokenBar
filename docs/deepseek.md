---
summary: "DeepSeek provider data sources: API balance and Dashboard usage."
read_when:
  - Adding or tweaking DeepSeek balance parsing
  - Updating Dashboard login or usage parsing
  - Updating API key handling
  - Documenting new provider behavior
---

# DeepSeek provider

DeepSeek supports API balance data and Dashboard usage data. In Auto mode, TokenBar prefers the API when an API key
is configured, then falls back to the stored Dashboard login. Dashboard-only mode shows usage and cost history without
inventing a remaining balance; the balance still requires the API endpoint.

## Data sources

1. **API key** supplied via `DEEPSEEK_API_KEY` / `DEEPSEEK_KEY`, or selected from DeepSeek token accounts in `~/.tokenbar/config.json`.
2. **Balance endpoint**
   - `GET https://api.deepseek.com/user/balance`
   - Request headers: `Authorization: Bearer <api key>`, `Accept: application/json`
   - Response contains `is_available`, and a `balance_infos` array with per-currency entries
     (`total_balance`, `granted_balance`, `topped_up_balance`).
3. **Dashboard login**
   - TokenBar opens `https://platform.deepseek.com/usage` only after an explicit Login/Reconnect action.
   - The resulting platform token is stored in the macOS Keychain and read with a non-interactive query.
   - Dashboard requests provide current-month cost, token, request, model, and daily history data.

## Usage details

- The menu card shows total balance with the paid vs. granted breakdown:
  e.g. `$50.00 (Paid: $40.00 / Granted: $10.00)`.
- The API separates granted balance from topped-up balance; TokenBar labels these as granted vs. paid credit.
- When multiple currencies are present, USD is shown preferentially.
- If total balance is zero, TokenBar shows an add-credits message. If balance is nonzero but `is_available` is false, it shows "Balance unavailable for API calls".
- There is no session or weekly window — DeepSeek does not expose per-window quota via API.
- Token-account selection injects the selected key into the fetch environment; otherwise TokenBar reads `DEEPSEEK_API_KEY` / `DEEPSEEK_KEY`.
- Without an API key, a stored Dashboard login still produces a valid web usage snapshot and the optional Cost section.
- Dashboard data does not contain the remaining account balance, so TokenBar leaves the Balance metric absent instead of
  displaying a fabricated zero.

## Key files

- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekProviderDescriptor.swift` (descriptor + fetch strategy)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekUsageFetcher.swift` (HTTP client + JSON parser)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekDashboardUsageFetcher.swift` (Dashboard usage and cost history)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekPlatformTokenManager.swift` (explicit WebView login + Keychain token)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekSettingsReader.swift` (env var resolution)
- `Sources/TokenBar/Providers/DeepSeek/DeepSeekProviderImplementation.swift` (provider presentation and login action)
- `Sources/TokenBarCore/TokenAccountSupportCatalog+Data.swift` (DeepSeek token-account injection)
