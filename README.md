# TokenBar 🎚️ — Your AI usage, in your menu bar

> macOS 14+ menu bar app for monitoring AI API usage across providers.
> Forked from [steipete/CodexBar](https://github.com/steipete/CodexBar) with **native Krill** and **Custom provider** support.

<img src="tokenbar.png" alt="TokenBar menu screenshot" width="520" />

## Supported Providers

TokenBar keeps your API limits visible at a glance. Enable what you use:

| Provider | Status | Notes |
|----------|--------|-------|
| **Codex** | Native | OpenAI Codex (OAuth + web) |
| **Claude** | Native | Anthropic Claude Code |
| **Krill** | 🆕 Native | Wallet balance, credits remaining, request stats |
| **Custom** | 🆕 | Any OpenAI-compatible endpoint |
| Cursor | Native | Cursor IDE |
| Gemini | Native | Google Gemini |
| Copilot | Native | GitHub Copilot |
| OpenRouter | Native | OpenRouter API |
| ... and 20+ more | | See [all providers](docs/) |

## What's New in TokenBar (vs CodexBar)

### 🆕 Krill Provider (Native)
- **WebView JWT login** — secure one-time login via Krill's website
- **Wallet balance** — $18.35 at a glance
- **Credits remaining** — Elite plan credits progress bar
- **Monthly requests** — 尊享月卡 request count tracking
- **Cache rate & today's spending** — detailed usage breakdown
- JWT stored securely in macOS Keychain, auto-refresh on expiry

### 🆕 Custom Provider
Add any OpenAI-compatible endpoint to `~/.tokenbar/config.json`:

```json
{
  "id": "custom",
  "enabled": false,
  "customName": "Your Provider",
  "baseURL": "https://api.example.com/v1",
  "apiKey": "sk-...",
  "customModelFilter": "gpt-4"
}
```

## Quick Start

```bash
# Build and run
cd TokenBar
swift build
./.build/debug/TokenBar

# Or use the build script
./Scripts/compile_and_run.sh
```

TokenBar runs in your menu bar (no Dock icon). Configure providers via **Settings** (⌘,).

## Configuration

Provider settings are stored in `~/.tokenbar/config.json`. See `config.example.json` for available options.

## Credits

- **Original project**: [steipete/CodexBar](https://github.com/steipete/CodexBar) by Peter Steinberger
- **License**: MIT (retained from upstream)
- **Contributor**: [@y0shua1ee](https://github.com/y0shua1ee)

## License

MIT © 2026 — see [LICENSE](LICENSE)
