# External Integrations

**Analysis Date:** 2026-06-15

## APIs & External Services

**Provider Usage, Billing, and Quota APIs:**
- Multi-provider fetch layer - Provider descriptors register 49 provider IDs in `Sources/TokenBarCore/Providers/Providers.swift` and `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`; fetch strategies run through `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`.
  - SDK/Client: `ProviderHTTPClient` / `URLSession` in `Sources/TokenBarCore/ProviderHTTPClient.swift`, provider-specific fetchers under `Sources/TokenBarCore/Providers/*`, WebKit in `Sources/TokenBarCore/OpenAIWeb/*`, and subprocess/PTY runners in `Sources/TokenBarCore/Host/*`.
  - Auth: `~/.tokenbar/config.json` via `Sources/TokenBarCore/Config/CodexBarConfig.swift`, provider env vars via `Sources/TokenBarCore/Config/ProviderConfigEnvironment.swift`, token resolution via `Sources/TokenBarCore/Providers/ProviderTokenResolver.swift`, Keychain cache via `Sources/TokenBarCore/KeychainCacheStore.swift`, browser cookies via SweetCookieKit, CLI session files, OAuth credentials, and local provider config files.
- OpenAI / ChatGPT / Codex - API Platform organization costs/usage, legacy credit grants, ChatGPT Codex usage, OpenAI web dashboard extras, Codex CLI RPC, and local Codex JSONL cost scans.
  - SDK/Client: `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIUsageFetcher.swift`, `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPICreditBalanceFetcher.swift`, `Sources/TokenBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/Providers/Codex/CodexStatusProbe.swift`, and `Sources/TokenBarCore/Vendored/CostUsage/*`.
  - Auth: `OPENAI_ADMIN_KEY`, `OPENAI_API_KEY`, `OPENAI_PROJECT_ID`, `~/.tokenbar/config.json`, `$CODEX_HOME/auth.json` or `~/.codex/auth.json`, `CODEX_CLI_PATH`, browser cookies for `chatgpt.com` / `openai.com`, and Keychain cache account `cookie.codex`.
- Anthropic / Claude - Claude Admin API reports, Claude OAuth usage, Claude web API, Claude CLI PTY usage, and local Claude JSONL cost scans.
  - SDK/Client: `Sources/TokenBarCore/Providers/Claude/ClaudeAdminAPIUsageFetcher.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeWeb/ClaudeWebAPIFetcher.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeStatusProbe.swift`, and `Sources/TokenBarCore/Vendored/CostUsage/*`.
  - Auth: `ANTHROPIC_ADMIN_KEY`, `ANTHROPIC_ADMIN_API_KEY`, `TOKENBAR_CLAUDE_OAUTH_TOKEN`, `TOKENBAR_CLAUDE_OAUTH_SCOPES`, `TOKENBAR_CLAUDE_OAUTH_CLIENT_ID`, `CLAUDE_CLI_PATH`, `CLAUDE_CONFIG_DIR`, `~/.claude/.credentials.json`, Claude CLI Keychain item `Claude Code-credentials`, browser cookies for `claude.ai`, and Keychain cache account `cookie.claude`.
- Google / Gemini / Vertex AI / Antigravity - Gemini CLI OAuth-backed quota API, Antigravity local LSP/HTTP usage probe, Vertex AI Cloud Monitoring quotas, and Google OAuth token refresh.
  - SDK/Client: `Sources/TokenBarCore/Providers/Gemini/GeminiStatusProbe.swift`, `Sources/TokenBarCore/Providers/Antigravity/AntigravityStatusProbe.swift`, `Sources/TokenBarCore/Providers/Antigravity/AntigravityCLISession.swift`, `Sources/TokenBarCore/Providers/VertexAI/VertexAIOAuth/VertexAIUsageFetcher.swift`, and `Sources/TokenBarCore/Providers/VertexAI/VertexAIOAuth/VertexAITokenRefresher.swift`.
  - Auth: Gemini CLI credentials, `GEMINI_CLI_PATH`, Antigravity OAuth credential JSON through `ANTIGRAVITY_OAUTH_CREDENTIALS_JSON`, `ANTIGRAVITY_CLI_PATH`, gcloud application-default credentials, Google OAuth token endpoint, and local Claude logs for Vertex AI cost attribution.
- GitHub Copilot - Device-flow OAuth and Copilot internal user quota endpoint.
  - SDK/Client: `Sources/TokenBarCore/Providers/Copilot/CopilotDeviceFlow.swift` and `Sources/TokenBarCore/Providers/Copilot/CopilotUsageFetcher.swift`.
  - Auth: `COPILOT_API_TOKEN`, `providers[].apiKey`, `providers[].enterpriseHost`, token accounts, device-flow token storage in app config, and optional enterprise host settings.
- AWS Bedrock / Kiro - AWS Cost Explorer for Bedrock spend and Kiro CLI usage output.
  - SDK/Client: `Sources/TokenBarCore/Providers/Bedrock/BedrockUsageStats.swift`, `Sources/TokenBarCore/Providers/Bedrock/BedrockAWSSigner.swift`, `Sources/TokenBarCore/Providers/Bedrock/BedrockCredentialResolver.swift`, and `Sources/TokenBarCore/Providers/Kiro/KiroStatusProbe.swift`.
  - Auth: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_PROFILE`, `TOKENBAR_BEDROCK_AUTH_MODE`, `TOKENBAR_BEDROCK_BUDGET`, `TOKENBAR_BEDROCK_API_URL`, `AWS_CLI_PATH`, Kiro CLI login state, and `kiro-cli` on PATH.
- API-key providers - z.ai, MiniMax, Alibaba Coding Plan fallback, Kilo, Kimi K2, Moonshot, Ollama Cloud, Synthetic, OpenRouter, ElevenLabs, DeepSeek, Codebuff, Crof, Venice, Doubao, GroqCloud, LLM Proxy, Deepgram, Azure OpenAI, and custom providers.
  - SDK/Client: provider fetchers under `Sources/TokenBarCore/Providers/Zai`, `Sources/TokenBarCore/Providers/MiniMax`, `Sources/TokenBarCore/Providers/Alibaba`, `Sources/TokenBarCore/Providers/Kilo`, `Sources/TokenBarCore/Providers/KimiK2`, `Sources/TokenBarCore/Providers/Moonshot`, `Sources/TokenBarCore/Providers/Ollama`, `Sources/TokenBarCore/Providers/Synthetic`, `Sources/TokenBarCore/Providers/OpenRouter`, `Sources/TokenBarCore/Providers/ElevenLabs`, `Sources/TokenBarCore/Providers/DeepSeek`, `Sources/TokenBarCore/Providers/Codebuff`, `Sources/TokenBarCore/Providers/Crof`, `Sources/TokenBarCore/Providers/Venice`, `Sources/TokenBarCore/Providers/Doubao`, `Sources/TokenBarCore/Providers/Groq`, `Sources/TokenBarCore/Providers/LLMProxy`, `Sources/TokenBarCore/Providers/Deepgram`, `Sources/TokenBarCore/Providers/AzureOpenAI`, and `Sources/TokenBarCore/Providers/Custom`.
  - Auth: provider env vars and `~/.tokenbar/config.json`, including `Z_AI_API_KEY`, `MINIMAX_API_KEY`, `MINIMAX_CODING_API_KEY`, `ALIBABA_CODING_PLAN_API_KEY`, `ALIBABA_QWEN_API_KEY`, `DASHSCOPE_API_KEY`, `KILO_API_KEY`, `KIMI_K2_API_KEY`, `KIMI_API_KEY`, `MOONSHOT_API_KEY`, `OLLAMA_API_KEY`, `SYNTHETIC_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_MANAGEMENT_KEY`, `OPENROUTER_ACTIVITY_API_KEY`, `ELEVENLABS_API_KEY`, `XI_API_KEY`, `DEEPSEEK_API_KEY`, `CODEBUFF_API_KEY`, `CROF_API_KEY`, `VENICE_API_KEY`, `DOUBAO_API_KEY`, `ARK_API_KEY`, `GROQ_API_KEY`, `LLM_PROXY_API_KEY`, `DEEPGRAM_API_KEY`, `AZURE_OPENAI_API_KEY`, and custom `providers[].baseURL` / `providers[].apiKey`.
- Browser-cookie providers - Cursor, OpenCode, OpenCode Go, Alibaba Token Plan, Factory, Devin, Manus, Kimi, Augment web fallback, Amp, T3 Chat, Ollama web quotas, Perplexity, Xiaomi MiMo, Abacus AI, Mistral, Command Code, Grok web fallback, Windsurf, and OpenAI web extras.
  - SDK/Client: SweetCookieKit through `Sources/TokenBarCore/BrowserDetection.swift`, `Sources/TokenBarCore/BrowserCookieAccessGate.swift`, provider cookie importers under `Sources/TokenBarCore/Providers/*/*CookieImporter.swift`, and WebKit where a web session/store is needed.
  - Auth: browser cookies from Safari, Chromium-family browsers, Firefox, Edge, provider manual `cookieHeader` values, provider-specific env cookie/session variables, localStorage importers, and Keychain cache entries keyed by provider.

**Provider Status Services:**
- Statuspage.io feeds - Polled for providers with `statusPageURL` in descriptors, including OpenAI/Codex, OpenAI API, Claude, Cursor, Factory, and Copilot.
  - SDK/Client: `UsageStore.fetchStatus` in `Sources/TokenBar/UsageStore+Status.swift` and `StatusFetcher` in `Sources/TokenBarCLI/CLIPayloads.swift`.
  - Auth: None.
- Google Workspace incidents feed - Used for Gemini/Antigravity product incidents.
  - SDK/Client: `UsageStore.fetchWorkspaceStatus` in `Sources/TokenBar/UsageStore+Status.swift`.
  - Auth: None.
- Link-only provider status pages - Descriptors expose `statusLinkURL` for Azure OpenAI, Gemini, Antigravity, OpenRouter, Perplexity, Mistral, DeepSeek, Alibaba, ElevenLabs, Vertex AI, Bedrock, Kiro, Grok, Groq, and other provider links in `Sources/TokenBarCore/Providers/*/*ProviderDescriptor.swift`.
  - SDK/Client: Menu actions open links from `Sources/TokenBar/StatusItemController+Actions.swift`.
  - Auth: None.

**Release, Distribution, and Upstream Services:**
- GitHub Releases - Hosts direct app zips, dSYM archives, CLI tarballs, checksums, and release notes.
  - SDK/Client: `gh release create` / `gh release upload` in `Scripts/release.sh` and `.github/workflows/release-cli.yml`.
  - Auth: GitHub CLI/session locally and `GITHUB_TOKEN` in `.github/workflows/release-cli.yml`.
- Sparkle appcast - Direct app update feed generated from `appcast.xml` and GitHub release assets.
  - SDK/Client: Sparkle framework in `Sources/TokenBar/TokenBarApp.swift`, `generate_appcast` in `Scripts/make_appcast.sh`, and appcast validation in `Scripts/verify_appcast.sh`.
  - Auth: Ed25519 private key path via `SPARKLE_PRIVATE_KEY_FILE`; public key is embedded by `Scripts/package_app.sh`.
- Apple Developer ID notarization - Direct macOS app release signing and notarization.
  - SDK/Client: `codesign`, `xcrun notarytool`, `stapler`, `spctl`, and `ditto` in `Scripts/sign-and-notarize.sh` and `Scripts/package_app.sh`.
  - Auth: `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, Developer ID certificate identity, and local Keychain certificate access.
- Homebrew tap - App cask and CLI formula update flow for `y0shua1ee/homebrew-tokenbar`.
  - SDK/Client: workflow dispatch from `.github/workflows/release-cli.yml`, plus verification steps in `docs/RELEASING.md` and `docs/releasing-homebrew.md`.
  - Auth: `HOMEBREW_TAP_TOKEN` in `.github/workflows/release-cli.yml`.
- Upstream monitoring - Scheduled checks for `steipete/CodexBar` and `nguyenphutrong/quotio`.
  - SDK/Client: `.github/workflows/upstream-monitor.yml`, `Scripts/check_upstreams.sh`, `Scripts/review_upstream.sh`, and `Scripts/analyze_quotio.sh`.
  - Auth: GitHub Actions `issues: write` permission for issue creation/update.

## Data Storage

**Databases:**
- Local JSON config - `~/.tokenbar/config.json` stores provider ordering, enabled state, API keys, manual cookie headers, source settings, token accounts, regions, and workspace IDs; implementation in `Sources/TokenBarCore/Config/CodexBarConfig.swift` and `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`.
  - Connection: `TOKENBAR_CONFIG` path override.
  - Client: `CodexBarConfigStore` and CLI config commands in `Sources/TokenBarCLI/CLIConfigCommand.swift`.
- macOS Keychain - Generic-password items are used for TokenBar-owned cache entries and legacy cookie/API-token entries.
  - Connection: Keychain service `com.y0shua1ee.tokenbar.cache` in `Sources/TokenBarCore/KeychainCacheStore.swift` and legacy service `com.y0shua1ee.TokenBar` in `Sources/TokenBar/KeychainMigration.swift`.
  - Client: Security.framework helpers in `Sources/TokenBarCore/KeychainCacheStore.swift`, `Sources/TokenBarCore/KeychainNoUIQuery.swift`, and `Sources/TokenBarCore/KeychainAccessPreflight.swift`.
- Browser cookie stores - Automatic imports read known browser cookie locations by browser/profile when the user enables cookie-backed providers.
  - Connection: Safari `~/Library/Cookies/Cookies.binarycookies`, Chromium-family `~/Library/Application Support/<Browser>/*/Cookies`, and Firefox `~/Library/Application Support/Firefox/Profiles/*/cookies.sqlite`; browser detection logic in `Sources/TokenBarCore/BrowserDetection.swift`.
  - Client: SweetCookieKit through `BrowserCookieClient` calls in provider importers and `Sources/TokenBarCore/BrowserCookieAccessGate.swift`.
- Local provider/session files - Provider-specific local auth, session, and usage paths include `$CODEX_HOME` / `~/.codex`, `CLAUDE_CONFIG_DIR` / `~/.claude`, `~/.config/claude`, `~/.pi/agent/sessions`, `~/.grok`, `~/.local/share/kilo/auth.json`, `~/.config/manicode/credentials.json`, gcloud ADC files, browser localStorage, and JetBrains IDE config directories.
  - Connection: Path and reader code in `Sources/TokenBarCore/PathEnvironment.swift`, `Sources/TokenBarCore/Vendored/CostUsage/*`, and provider-specific files under `Sources/TokenBarCore/Providers/*`.
  - Client: `FileManager`, `SQLite3`, provider parsers, `CostUsageFetcher`, `PiSessionCostScanner`, and provider local storage importers.

**File Storage:**
- App Group widget snapshot - `Sources/TokenBarCore/AppGroupSupport.swift` resolves group IDs and snapshot locations; `Sources/TokenBarCore/WidgetSnapshot.swift` reads/writes `widget-snapshot.json` for `Sources/TokenBarWidget/*`.
- App support fallback - `Sources/TokenBarCore/AppGroupSupport.swift` falls back to `~/Library/Application Support/TokenBar` when an App Group container is unavailable.
- Cost usage caches - Codex/Claude/pi cost scans cache under `~/Library/Caches/CodexBar/cost-usage/` as documented in `docs/codex.md` and implemented by `Sources/TokenBarCore/Vendored/CostUsage/*`.
- Logs - Optional file logs write to `~/Library/Logs/TokenBar/TokenBar.log` through `Sources/TokenBarCore/Logging/FileLogHandler.swift`.
- Release artifacts - App zips, dSYM zips, `TokenBar.app`, and `appcast.xml` are generated by `Scripts/package_app.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, and `Scripts/release_artifacts.sh`.

**Caching:**
- Keychain cookie/OAuth cache - `Sources/TokenBarCore/KeychainCacheStore.swift` stores Codable entries under account names such as `cookie.<provider>` and OAuth-specific keys.
- Browser cookie denial cooldown - `Sources/TokenBarCore/BrowserCookieAccessGate.swift` persists temporary browser denial windows in `UserDefaults` key `browserCookieAccessDeniedUntil`.
- Claude OAuth rate-limit/backoff cache - `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/*Gate.swift` stores cooldown state in `UserDefaults`.
- CLI serve response cache - `Sources/TokenBarCLI/CLIServeCommand.swift` keeps in-memory fresh and last-good responses for localhost `/usage` and `/cost` routes.
- WebKit dashboard stores - `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardWebsiteDataStore.swift` and `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardBrowserCookieImporter.swift` manage per-account dashboard cookies and WebKit stores.

## Authentication & Identity

**Auth Provider:**
- Custom per-provider auth routing - No single external identity provider owns the app; each provider uses its own API key, OAuth token, browser cookie, local CLI session, local config file, device flow, or cloud credential.
  - Implementation: `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`, `Sources/TokenBarCore/Providers/ProviderTokenResolver.swift`, `Sources/TokenBarCore/Config/ProviderConfigEnvironment.swift`, and provider descriptors/fetchers under `Sources/TokenBarCore/Providers/*`.
- API key and token-account auth - API tokens are read from `~/.tokenbar/config.json`, stdin through CLI commands, env vars, or provider token accounts.
  - Implementation: `Sources/TokenBarCore/Config/CodexBarConfig.swift`, `Sources/TokenBarCore/TokenAccounts.swift`, `Sources/TokenBarCore/TokenAccountSupport.swift`, and `Sources/TokenBarCLI/CLIConfigCommand.swift`.
- OAuth/device-flow auth - Codex, Claude, Vertex AI, Gemini, Copilot, Antigravity, Grok, and provider-specific flows refresh or read OAuth/session credentials.
  - Implementation: `Sources/TokenBarCore/Providers/Codex/CodexOAuth/*`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/*`, `Sources/TokenBarCore/Providers/VertexAI/VertexAIOAuth/*`, `Sources/TokenBarCore/Providers/Gemini/GeminiStatusProbe.swift`, `Sources/TokenBarCore/Providers/Copilot/CopilotDeviceFlow.swift`, `Sources/TokenBarCore/Providers/Antigravity/AntigravityOAuthCredentialsStore.swift`, and `Sources/TokenBarCore/Providers/Grok/GrokAuth.swift`.
- Browser-cookie auth - Automatic and manual cookie sources are modeled by `ProviderCookieSource` and provider settings; cookie imports are gated to avoid unnecessary Keychain prompts.
  - Implementation: `Sources/TokenBarCore/Providers/ProviderCookieSource.swift`, `Sources/TokenBarCore/BrowserDetection.swift`, `Sources/TokenBarCore/BrowserCookieAccessGate.swift`, and provider cookie importers under `Sources/TokenBarCore/Providers/*`.
- Keychain prompt safety - Keychain reads use no-UI query policy where possible, a global "Disable Keychain access" gate, preflight checks, and prompt handlers.
  - Implementation: `Sources/TokenBarCore/KeychainAccessGate.swift`, `Sources/TokenBarCore/KeychainNoUIQuery.swift`, `Sources/TokenBarCore/KeychainAccessPreflight.swift`, `Sources/TokenBar/KeychainPromptCoordinator.swift`, and `Tests/TokenBarTests/KeychainPromptSafetyAuditTests.swift`.

## Monitoring & Observability

**Error Tracking:**
- Not detected - No Sentry, Crashlytics, Rollbar, or external crash/error reporting dependency is declared in `Package.swift`, `Package.resolved`, or `.github/workflows/*`.

**Logs:**
- App logs - `Sources/TokenBar/TokenBarApp.swift` bootstraps `CodexBarLog` to OSLog subsystem `com.y0shua1ee.tokenbar`.
- CLI logs - `Sources/TokenBarCLI/CLIEntry.swift` bootstraps stderr or JSON stderr logging for CLI commands.
- File logs - Optional redacted file logging writes to `~/Library/Logs/TokenBar/TokenBar.log` through `Sources/TokenBarCore/Logging/FileLogHandler.swift`.
- Redaction - `Sources/TokenBarCore/Logging/LogRedactor.swift` redacts email addresses, Cookie headers, Authorization headers, Bearer tokens, and MiniMax token shapes before logging.
- Status observability - Provider status feeds are polled by `Sources/TokenBar/UsageStore+Status.swift`; menu/UI display lives in `Sources/TokenBar/StatusItemController.swift`, `Sources/TokenBar/MenuDescriptor.swift`, and `Sources/TokenBar/IconRenderer.swift`.

## CI/CD & Deployment

**Hosting:**
- GitHub Releases - Primary host for direct app assets, dSYM archives, CLI tarballs, and checksums; release automation in `Scripts/release.sh` and `.github/workflows/release-cli.yml`.
- GitHub raw appcast - Sparkle feed URL is generated as `https://raw.githubusercontent.com/y0shua1ee/TokenBar/main/appcast.xml` by `Scripts/package_app.sh`, `Scripts/make_appcast.sh`, and `Scripts/release.sh`.
- Homebrew tap - App cask and CLI formula are updated through `y0shua1ee/homebrew-tokenbar` from `.github/workflows/release-cli.yml`; release instructions live in `docs/RELEASING.md` and `docs/releasing-homebrew.md`.
- Static docs/site artifacts - Documentation and site files live in `docs`, with generation helpers in `Scripts/generate-llms.mjs`, `Scripts/docs-list.mjs`, and `docs/index.html`.

**CI Pipeline:**
- Main CI - `.github/workflows/ci.yml` runs lint/build/test on `macos-15-intel`, installs pinned SwiftFormat/SwiftLint, and runs Swift test suites through `Scripts/ci_swift_test_by_suite.py`.
- Linux CLI CI - `.github/workflows/ci.yml` installs Swift 6.2.1 through `swiftly`, builds `TokenBarCLI` with static Swift stdlib, runs Linux tests, and smoke-tests CLI behavior.
- CLI release artifacts - `.github/workflows/release-cli.yml` builds macOS and Linux CLI tarballs, uploads release assets, and dispatches the Homebrew tap update.
- Upstream monitor - `.github/workflows/upstream-monitor.yml` fetches `steipete/CodexBar` and `nguyenphutrong/quotio`, summarizes drift, and opens/updates GitHub issues.
- Local release - `Scripts/release.sh` requires a clean worktree, finalized changelog, monotonic appcast/build, lint, tests, notarization, tag/release creation, appcast generation, and asset verification.

## Environment Configuration

**Required env vars:**
- Config path: `TOKENBAR_CONFIG` in `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`.
- Logging/debug: `TOKENBAR_LOG_LEVEL`, `TOKENBAR_ALLOW_TEST_KEYCHAIN_ACCESS`, `TOKENBAR_ALLOW_BROWSER_COOKIE_IMPORT`, and provider/debug flags such as `TOKENBAR_DEBUG_OPENROUTER_ERROR_BODIES`.
- Provider API credentials: `OPENAI_ADMIN_KEY`, `OPENAI_API_KEY`, `OPENAI_PROJECT_ID`, `ANTHROPIC_ADMIN_KEY`, `ANTHROPIC_ADMIN_API_KEY`, `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`, `AZURE_OPENAI_API_VERSION`, `Z_AI_API_KEY`, `Z_AI_API_HOST`, `Z_AI_QUOTA_URL`, `MINIMAX_API_KEY`, `MINIMAX_CODING_API_KEY`, `KILO_API_KEY`, `KIMI_K2_API_KEY`, `KIMI_API_KEY`, `MOONSHOT_API_KEY`, `MOONSHOT_REGION`, `OLLAMA_API_KEY`, `SYNTHETIC_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_MANAGEMENT_KEY`, `OPENROUTER_ACTIVITY_API_KEY`, `ELEVENLABS_API_KEY`, `XI_API_KEY`, `DEEPSEEK_API_KEY`, `CODEBUFF_API_KEY`, `CROF_API_KEY`, `CROFAI_API_KEY`, `VENICE_API_KEY`, `DOUBAO_API_KEY`, `ARK_API_KEY`, `GROQ_API_KEY`, `LLM_PROXY_API_KEY`, `LLM_PROXY_BASE_URL`, `DEEPGRAM_API_KEY`, and `DEEPGRAM_PROJECT_ID`.
- AWS/Bedrock: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_PROFILE`, `TOKENBAR_BEDROCK_AUTH_MODE`, `TOKENBAR_BEDROCK_BUDGET`, and `TOKENBAR_BEDROCK_API_URL`.
- Cookie/session providers: examples include `ALIBABA_CODING_PLAN_COOKIE`, `ALIBABA_TOKEN_PLAN_COOKIE`, `MANUS_SESSION_TOKEN`, `MANUS_COOKIE`, `PERPLEXITY_SESSION_TOKEN`, `PERPLEXITY_COOKIE`, `MINIMAX_COOKIE`, `STEPFUN_USERNAME`, `STEPFUN_PASSWORD`, `STEPFUN_TOKEN`, and provider-specific manual `cookieHeader` fields in `~/.tokenbar/config.json`.
- CLI paths: `CODEX_CLI_PATH`, `CLAUDE_CLI_PATH`, `GEMINI_CLI_PATH`, `ANTIGRAVITY_CLI_PATH`, `GROK_CLI_PATH`, `AWS_CLI_PATH`, and `AUGGIE_CLI_PATH`.
- Release/build: `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `SPARKLE_PRIVATE_KEY_FILE`, `APP_IDENTITY`, `APP_TEAM_ID`, `ARCHES`, `TOKENBAR_SIGNING`, `TOKENBAR_FORCE_CLEAN`, `TOKENBAR_ALLOW_LLDB`, `TOKENBAR_WIDGET_EXTENSION_TIMEOUT_SECONDS`, `SPARKLE_CHANNEL`, `SPARKLE_RELEASE_VERSION`, `SPARKLE_DOWNLOAD_URL_PREFIX`, and `RUN_SPARKLE_UPDATE_TEST`.
- GitHub Actions: `GITHUB_TOKEN` and `HOMEBREW_TAP_TOKEN` in `.github/workflows/release-cli.yml`.

**Secrets location:**
- Main config secrets: `~/.tokenbar/config.json` with `0600` permissions; schema in `Sources/TokenBarCore/Config/CodexBarConfig.swift`; example placeholders in `config.example.json`.
- TokenBar Keychain cache: service `com.y0shua1ee.tokenbar.cache` in `Sources/TokenBarCore/KeychainCacheStore.swift`.
- Legacy TokenBar Keychain items: service `com.y0shua1ee.TokenBar` listed in `Sources/TokenBar/KeychainMigration.swift`.
- Browser cookies/local storage: browser profile paths detected by `Sources/TokenBarCore/BrowserDetection.swift` and provider importers under `Sources/TokenBarCore/Providers/*`.
- CLI/local provider credentials: `$CODEX_HOME` / `~/.codex`, `CLAUDE_CONFIG_DIR` / `~/.claude`, `~/.config/claude`, `~/.grok`, `~/.local/share/kilo/auth.json`, `~/.config/manicode/credentials.json`, gcloud ADC files, and AWS profile/config/credential sources.
- Release secrets: `.mac-release.env` exists and was not read; release scripts also use Keychain certificate identities and the `SPARKLE_PRIVATE_KEY_FILE` path.

## Webhooks & Callbacks

**Incoming:**
- Local CLI HTTP server - `tokenbar serve` binds to `127.0.0.1` only and accepts loopback `Host` headers for `GET /health`, `GET /usage`, `GET /usage?provider=...`, `GET /cost`, and `GET /cost?provider=...`; implementation in `Sources/TokenBarCLI/CLIServeCommand.swift` and `Sources/TokenBarCLI/CLILocalHTTPServer.swift`.
- GitHub release event - `.github/workflows/release-cli.yml` runs on published GitHub releases and manual `workflow_dispatch`.
- Upstream monitor schedule - `.github/workflows/upstream-monitor.yml` runs on cron and manual dispatch.
- Provider OAuth callbacks: Not detected as a local HTTP callback server; device/OAuth flows use provider endpoints, stored credentials, CLI credentials, or browser/session state.

**Outgoing:**
- Provider usage and billing requests - Sent by provider fetchers under `Sources/TokenBarCore/Providers/*`, `Sources/TokenBarCore/OpenAIWeb/*`, and `Sources/TokenBarCore/ProviderHTTPClient.swift`.
- Browser/WebKit requests - Hidden WebKit dashboard sessions and cookie import checks run through `Sources/TokenBarCore/OpenAIWeb/*` and provider-specific web fetchers.
- Provider CLI subprocesses - `codex`, `claude`, `gemini`, `agy`, `grok`, `aws`, `auggie`, `kiro-cli`, and similar local tools are located by `Sources/TokenBarCore/PathEnvironment.swift` and executed through `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift` or `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`.
- Status feeds - Statuspage.io and Google Workspace incidents are fetched by `Sources/TokenBar/UsageStore+Status.swift` and `Sources/TokenBarCLI/CLIPayloads.swift`.
- Release publishing - GitHub release creation/upload, Sparkle appcast generation, Apple notarization, and Homebrew tap dispatch are implemented by `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, and `.github/workflows/release-cli.yml`.

---

*Integration audit: 2026-06-15*
