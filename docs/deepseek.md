---
summary: "DeepSeek provider data sources: API key + balance endpoint."
read_when:
  - Adding or tweaking DeepSeek balance parsing
  - Updating API key handling
  - Documenting new provider behavior
---

# DeepSeek provider

DeepSeek is API-only. Balance is reported by `GET https://api.deepseek.com/user/balance`,
so TokenBar only needs a valid API key to show your remaining credit balance.

## Data sources

1. **API key** supplied via `DEEPSEEK_API_KEY` / `DEEPSEEK_KEY`, or selected from DeepSeek token accounts in `~/.tokenbar/config.json`.
2. **Balance endpoint**
   - `GET https://api.deepseek.com/user/balance`
   - Request headers: `Authorization: Bearer <api key>`, `Accept: application/json`
   - Response contains `is_available`, and a `balance_infos` array with per-currency entries
     (`total_balance`, `granted_balance`, `topped_up_balance`).

## Usage details

- The menu card shows total balance with the paid vs. granted breakdown:
  e.g. `$50.00 (Paid: $40.00 / Granted: $10.00)`.
- The API separates granted balance from topped-up balance; TokenBar labels these as granted vs. paid credit.
- When multiple currencies are present, USD is shown preferentially.
- If total balance is zero, TokenBar shows an add-credits message. If balance is nonzero but `is_available` is false, it shows "Balance unavailable for API calls".
- There is no session or weekly window — DeepSeek does not expose per-window quota via API.
- Token-account selection injects the selected key into the fetch environment; otherwise TokenBar reads `DEEPSEEK_API_KEY` / `DEEPSEEK_KEY`.

## Key files

- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekProviderDescriptor.swift` (descriptor + fetch strategy)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekUsageFetcher.swift` (HTTP client + JSON parser)
- `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekSettingsReader.swift` (env var resolution)
- `Sources/TokenBar/Providers/DeepSeek/DeepSeekProviderImplementation.swift` (provider activation and token-account visibility)
- `Sources/TokenBarCore/TokenAccountSupportCatalog+Data.swift` (DeepSeek token-account injection)
