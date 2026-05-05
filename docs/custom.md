---
summary: "Custom provider: any OpenAI-compatible endpoint with API key, balance, and model discovery."
read_when:
  - Setting up a custom OpenAI-compatible provider
  - Debugging custom provider balance/model fetching
  - Documenting custom provider behavior
---

# Custom provider

The Custom provider lets you add any OpenAI-compatible API endpoint to TokenBar.
Use it for self-hosted LLMs (vLLM, Ollama, LocalAI), regional proxies, or any service
that speaks the OpenAI API format.

## Configuration

Add a `custom` block to `~/.tokenbar/config.json`:

```json
{
  "id": "custom",
  "enabled": true,
  "customName": "Your Provider",
  "baseURL": "https://api.example.com/v1",
  "apiKey": "sk-...",
  "customModelFilter": "gpt-4"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Must be `"custom"` |
| `enabled` | Yes | `true` to activate |
| `customName` | No | Display name (defaults to "Custom") |
| `baseURL` | Yes | OpenAI-compatible base URL |
| `apiKey` | Yes | API key for the endpoint |
| `customModelFilter` | No | Filter models by substring (e.g. `"gpt-4"`) |

Settings can also be configured via TokenBar Settings → Providers → Custom.

## Data sources

The Custom provider uses two OpenAI-compatible endpoints:

1. **Models** (`GET {baseURL}/models`) — lists available models.
   Filtered by `customModelFilter` when set.
2. **Balance** — balance reporting varies by backend:
   - If no balance endpoint is available, a model count badge is shown instead.
   - Some backends expose balance via custom endpoints; TokenBar attempts
     common patterns but the primary display is model availability.

## Usage details

- The menu card shows the provider name, model count (or balance if available).
- No session/weekly quota tracking — that depends on the specific backend.
- API key is stored in `~/.tokenbar/config.json` (plaintext).
  Consider using a local-only key with minimal permissions.
- The Custom provider is **not** bundled with any default endpoint —
  you must configure it yourself.

## Common backends

- **Ollama**: `http://localhost:11434/v1` (no API key needed)
- **vLLM**: `http://localhost:8000/v1`
- **LocalAI**: `http://localhost:8080/v1`
- **Groq**: `https://api.groq.com/openai/v1`
- **Together AI**: `https://api.together.xyz/v1`

## Key files

- `Sources/TokenBarCore/Providers/Custom/CustomProviderDescriptor.swift` (descriptor)
- `Sources/TokenBarCore/Providers/Custom/CustomUsageFetcher.swift` (HTTP client + model/balance fetcher)
- `Sources/TokenBar/Providers/Custom/CustomProviderImplementation.swift` (settings UI)
