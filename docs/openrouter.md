---
summary: "OpenRouter provider: API key credits, rate limits, and daily/weekly/monthly spend."
read_when:
  - Debugging OpenRouter API key usage or spend parsing
  - Updating OpenRouter credits or key-limit display
  - Explaining OpenRouter setup and environment variables
---

# OpenRouter Provider

[OpenRouter](https://openrouter.ai) is a unified API that provides access to multiple AI models from different providers (OpenAI, Anthropic, Google, Meta, and more) through a single endpoint.

## Authentication

OpenRouter uses API key authentication. Get your API key from [OpenRouter Settings](https://openrouter.ai/settings/keys).

Detailed Activity usage requires an OpenRouter management key. A regular API key can read credits and key limits, while the Activity endpoint may return `403` until the key has management permissions.

### Environment Variable

Set the `OPENROUTER_API_KEY` environment variable:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

### Settings

You can configure both keys in TokenBar Settings → Providers → OpenRouter:

- **API key** powers credits and current-key quota.
- **Management API key** powers Activity cost history across the account, and can also power credits when no regular API key is configured. This must be an OpenRouter management key; a normal generation/API key returns `HTTP 403: Only management keys can fetch activity for an account`.

### CLI config

```bash
printf '%s' "$OPENROUTER_API_KEY" | tokenbar config set-api-key --provider openrouter --stdin
```

## Data Source

The OpenRouter provider fetches usage data from three API endpoints:

1. **Credits API** (`/api/v1/credits`): Returns total credits purchased and total usage. The balance is calculated as `total_credits - total_usage`.

2. **Key API** (`/api/v1/key`): Returns rate limit information plus current daily, weekly, and monthly spend for your API key.

3. **Activity API** (`/api/v1/activity`): Returns cost, token, request, provider, and model activity grouped by endpoint for the last 30 completed UTC days. TokenBar uses this data for the Cost section and cost history chart when a management key is available.

## Display

The OpenRouter menu card shows:

- **Primary meter**: API key limit usage when the key has a configured limit
- **Spend notes**: Daily, weekly, and monthly API key spend when OpenRouter returns those fields
- **Spend chart**: Day/week/month spend can reuse the shared inline dashboard when enough history is available
- **Balance**: Displayed in the identity section as "Balance: $X.XX"
- **Cost section**: Latest completed day and last 30 completed UTC days, including spend, tokens, request counts, and model breakdowns from the Activity API

## CLI Usage

```bash
tokenbar --provider openrouter
tokenbar -p or  # alias
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENROUTER_API_KEY` | Your OpenRouter API key (optional when a management key is configured) |
| `OPENROUTER_MANAGEMENT_KEY` | Management key for `/api/v1/activity` cost/token/request history (optional; preferred for Activity) |
| `OPENROUTER_ACTIVITY_API_KEY` | Alternate Activity API key env var (optional) |
| `OPENROUTER_API_URL` | Override the base API URL (optional, defaults to `https://openrouter.ai/api/v1`) |
| `OPENROUTER_HTTP_REFERER` | Optional client referer sent as `HTTP-Referer` header |
| `OPENROUTER_X_TITLE` | Optional client title sent as `X-Title` header (defaults to `TokenBar`) |

## Notes

- Credit values are cached on OpenRouter's side and may be up to 60 seconds stale
- OpenRouter uses a credit-based billing system where you pre-purchase credits
- Rate limits depend on your credit balance (10+ credits = 1000 free model requests/day)
- Activity data is grouped by endpoint for completed UTC days; today's live usage may appear after OpenRouter completes the UTC day
- TokenBar includes `usage` and `byok_usage_inference` in Activity spend totals
