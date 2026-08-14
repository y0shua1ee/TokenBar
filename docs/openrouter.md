---
summary: "OpenRouter provider: regular-key balance/quota plus account-level Activity history."
read_when:
  - Debugging OpenRouter API key balance, quota, or Activity parsing
  - Configuring an OpenRouter regular API key or Management key
  - Explaining OpenRouter credential scope and environment variables
---

# OpenRouter Provider

[OpenRouter](https://openrouter.ai) is a unified API that provides access to models from multiple providers through a
single endpoint. TokenBar supports two separate OpenRouter credentials with intentionally different scopes.

## Authentication

### Regular API key

Create a regular key in [OpenRouter API Keys](https://openrouter.ai/settings/keys). TokenBar uses this key for:

- Credits balance from `/api/v1/credits`
- The current key's spending limit and daily, weekly, and monthly usage from `/api/v1/key`
- Independently fetching each labeled key in TokenBar's multi-account view

This is the same type of key OpenRouter accepts for inference, but TokenBar only uses it for the balance and current-key
quota requests listed above.

Set the key in TokenBar Settings → Providers → OpenRouter, or use `OPENROUTER_API_KEY`:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

### Management key for Activity

Create a separate key in [OpenRouter Management Keys](https://openrouter.ai/settings/management-keys). TokenBar uses it
only for account-level `/api/v1/activity` analytics covering the last 30 **completed** UTC days.

[OpenRouter's Management key documentation](https://openrouter.ai/docs/guides/overview/auth/management-api-keys)
states that these keys cannot call completion endpoints. TokenBar does not send this key to Credits, current-key quota,
completion, or custom endpoint requests. The Activity request always uses OpenRouter's hosted API.

Set the key in the secure **Management key (Activity)** field, or use:

```bash
export OPENROUTER_MANAGEMENT_KEY="<management-key>"
```

The two credentials are optional and independent:

- Regular key only: balance and current-key quota, without account Activity history.
- Management key only: account-level Activity history, without balance or current-key quota. This Activity-only setup
  is sufficient to enable the provider.
- Both keys: balance/current-key quota plus account-level Activity history.

## Multiple regular API keys

To monitor multiple OpenRouter keys, add labeled API keys in the same provider settings. TokenBar fetches each regular
key independently. Choose the segmented account switcher or stacked account cards under Settings → Display.

```bash
printf '%s' "$OPENROUTER_API_KEY" | tokenbar config set-api-key --provider openrouter --stdin
```

Management Activity is account-level. It is not attributed to or copied onto individual labeled API-key cards.

## Data sources

TokenBar can combine three official endpoints:

1. **Credits API** (`/api/v1/credits`, regular key): Returns total credits purchased and total usage. TokenBar
   calculates balance as `total_credits - total_usage`.
2. **Current Key API** (`/api/v1/key`, regular key): Returns the authenticated key's spending limit and daily, weekly,
   and monthly usage. This is optional enrichment; a slow or unavailable response does not hide a successful balance.
3. **[Activity API](https://openrouter.ai/docs/api/api-reference/analytics/get-user-activity-grouped-by-endpoint)**
   (`/api/v1/activity`, Management key): Returns account-level cost, requests, tokens, and model activity for the last
   30 completed UTC days. The most recent value is therefore the latest completed UTC day, not today's partial spend.

## Display

Depending on the configured credentials, the OpenRouter menu card can show:

- API key limit usage when the regular key has a configured spending limit
- Daily, weekly, and monthly usage for the current regular key
- Credits balance
- Account-level Activity cost, request, token, model, and daily history for the last 30 completed UTC days

## CLI usage

```bash
tokenbar --provider openrouter
tokenbar -p or  # alias
tokenbar --provider openrouter --account Personal
tokenbar --provider openrouter --all-accounts --format json --pretty
tokenbar cost --provider openrouter --format json --pretty
```

The `cost` command uses only the Management key and returns provider-reported account Activity. Its JSON preserves the
history label plus daily and per-model cost, token, reasoning-token, and request metrics. Reasoning tokens remain a
separate metric but are already included in completion tokens, so they are not added to token totals a second time.

## Environment variables

| Variable | Description |
|----------|-------------|
| `OPENROUTER_API_KEY` | Regular API key for Credits balance and current-key quota (optional) |
| `OPENROUTER_MANAGEMENT_KEY` | Management key for account-level Activity only (optional) |
| `OPENROUTER_API_URL` | Override the regular-key API base URL (optional) |
| `OPENROUTER_HTTP_REFERER` | Optional client referer for regular-key requests |
| `OPENROUTER_X_TITLE` | Optional client title for regular-key requests (defaults to `TokenBar`) |

## Notes

- Credits values may be cached by OpenRouter and can be briefly stale.
- Activity covers completed UTC days, so it intentionally excludes the current partial UTC day.
- OpenRouter uses a credit-based billing system; spending limits belong to individual regular API keys, while Activity
  without an API-key hash is account-level.
