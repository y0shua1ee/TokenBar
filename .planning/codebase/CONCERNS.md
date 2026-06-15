# Codebase Concerns

**Analysis Date:** 2026-06-15

## Tech Debt

**Provider registration is spread across mirrored switch tables:**
- Issue: Adding or changing a provider requires coordinated edits across enum cases, metadata, implementation factories, settings descriptors, icon styles, CLI/config handling, and menu display seams.
- Files: `Sources/TokenBarCore/Providers/Providers.swift`, `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`, `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`, `Sources/TokenBar/Providers/Shared/ProviderCatalog.swift`, `Sources/TokenBar/ProviderRegistry.swift`, `Tests/TokenBarTests/ProviderRegistryTests.swift`, `Tests/TokenBarTests/ProviderSettingsDescriptorTests.swift`
- Impact: A missing entry can produce runtime preconditions, absent settings, missing labels, broken status menu rows, or untested provider-specific behavior.
- Fix approach: Treat `ProviderDescriptorRegistry` and `ProviderImplementationRegistry` as required provider-entry points. Extend the registry completeness tests whenever adding a provider, and keep provider-specific UI/actions in `Sources/TokenBar/Providers/<Provider>/` rather than adding more special cases to shared menu code.

**Status/menu controller owns too many state machines:**
- Issue: `StatusItemController` coordinates AppKit status items, SwiftUI hosting views, split/merged modes, menu tracking, refresh scheduling, animations, switcher state, provider actions, and login callbacks in one controller family.
- Files: `Sources/TokenBar/StatusItemController.swift`, `Sources/TokenBar/StatusItemController+Menu.swift`, `Sources/TokenBar/StatusItemController+MenuRefreshScheduling.swift`, `Sources/TokenBar/StatusItemController+MenuTracking.swift`, `Sources/TokenBar/StatusItemController+SwitcherViews.swift`, `Sources/TokenBar/MenuDescriptor.swift`
- Impact: Small menu changes can regress refresh timing, stale baselines, closed-menu prewarming, highlight state, or AppKit lifetime handling.
- Fix approach: Put new menu behavior behind stable model seams such as `MenuDescriptor`, `MenuCardModel`, provider implementation specs, and settings state. Use live `NSStatusBar`/`NSMenu` tests only for AppKit wiring; otherwise extend descriptor/model tests in `Tests/TokenBarTests`.

**Large files concentrate unrelated behavior:**
- Issue: Several implementation and test files exceed normal reviewable size and mix parsing, persistence, provider policy, UI state, and edge-case fixtures.
- Files: `Sources/TokenBarCore/Vendored/CostUsage/CostUsageScanner.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift`, `Sources/TokenBarCore/Providers/Factory/FactoryStatusProbe.swift`, `Sources/TokenBarCore/Providers/MiniMax/MiniMaxUsageFetcher.swift`, `Sources/TokenBar/UsageStore.swift`, `Tests/TokenBarTests/CostUsageScannerBreakdownTests.swift`, `Tests/TokenBarTests/MenuCardModelTests.swift`
- Impact: Review cost is high, targeted test failures are harder to localize, and concurrency/security changes require reading broad files to find all mutable state.
- Fix approach: Extract by responsibility only when touching the area for behavior changes. Keep parser fixtures, HTTP adapters, credential storage, and display projection in separate modules where local patterns already exist.

**CLI/path discovery contains high-complexity shell fallback logic:**
- Issue: Binary resolution uses explicit env overrides, cached login PATH, current PATH, well-known paths, `command -v`, alias resolution, fallback system paths, quarantine/malware xattr checks, and `spctl` assessment.
- Files: `Sources/TokenBarCore/PathEnvironment.swift`, `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`, `Tests/TokenBarTests/PathEnvironmentTests.swift`, `Tests/TokenBarTests/SubprocessRunnerTests.swift`, `Tests/TokenBarTests/TTYCommandRunnerTests.swift`
- Impact: GUI-launched app environments, shell init scripts, aliases, quarantined binaries, and background child processes create many platform-specific failure modes.
- Fix approach: Reuse `BinaryLocator`, `SubprocessRunner`, and `TTYCommandRunner` for new CLI integrations. Do not add ad hoc `Process` launch paths without equivalent timeout, pipe-drain, environment, and process-group cleanup behavior.

**Debug tooling is uneven across providers:**
- Issue: Some providers return rich debug dumps while many cases still return "debug log not yet implemented" from the shared debug dispatcher.
- Files: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/UsageStore+ClaudeDebug.swift`, `Sources/TokenBar/PreferencesDebugPane.swift`, `Sources/TokenBarCore/Providers/Augment/AugmentStatusProbe.swift`, `Sources/TokenBarCore/Providers/Cursor/CursorStatusProbe.swift`
- Impact: Support workflows have inconsistent evidence by provider, and richer debug paths risk leaking more private data than the placeholder paths.
- Fix approach: Add provider debug output through a small provider-owned formatter that redacts credentials and account identifiers before `UsageStore.dumpLog(toFileFor:)` writes to disk.

**Cross-agent state docs are template-only:**
- Issue: The handoff and decision docs contain templates but no durable session facts.
- Files: `.ai/HANDOFF.md`, `.ai/DECISIONS.md`, `AGENTS.md`
- Impact: Codex/Hermes handoffs depend on the git diff and conversation state instead of a local current-state record.
- Fix approach: After non-trivial code sessions, update `.ai/HANDOFF.md` with the current goal, changed files, tests run, and blockers. Update `.ai/DECISIONS.md` only for durable architecture, workflow, data model, API, auth, deployment, or testing decisions.

## Known Bugs

**No confirmed reproducible bugs detected from static audit:**
- Symptoms: Not detected.
- Files: `Sources/TokenBar`, `Sources/TokenBarCore`, `Sources/TokenBarCLI`, `Tests/TokenBarTests`, `Scripts`
- Trigger: Not applicable.
- Workaround: Track bug-shaped risks under `Fragile Areas`, `Security Considerations`, and `Test Coverage Gaps`; do not treat static risk notes as reproduced defects without a focused test or live reproduction.

## Security Considerations

**Plaintext provider secrets in local config:**
- Risk: Provider API keys, management keys, secret keys, cookie headers, token accounts, workspace IDs, and enterprise hosts are represented in the JSON config model and can be printed by config dump commands.
- Files: `Sources/TokenBarCore/Config/CodexBarConfig.swift`, `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`, `Sources/TokenBarCLI/CLIConfigCommand.swift`, `Sources/TokenBarCLI/CLIHelp.swift`
- Current mitigation: `CodexBarConfigStore.save(_:)` writes normalized JSON atomically and applies POSIX `0600` permissions. Key update logging uses value summaries instead of raw values.
- Recommendations: Do not use `tokenbar config dump` in automation unless the output path is private and intentionally reviewed. Add a redacted dump/export path before recommending diagnostics that include `CodexBarConfig`. Prefer Keychain-backed storage for high-risk fields such as API keys and cookie headers when adding new credential flows.

**Debug dumps write private provider data to temporary files:**
- Risk: User-triggered debug dumps can write raw provider probe output, raw JSON responses, dashboard HTML/body text, account email/plan details, or usage payload fragments to files under `/tmp`.
- Files: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/UsageStore+ClaudeDebug.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBar/OpenAICreditsPurchaseWindowController.swift`, `Sources/TokenBarCore/Providers/Augment/AugmentStatusProbe.swift`, `Sources/TokenBarCore/Providers/Cursor/CursorStatusProbe.swift`, `Sources/TokenBar/PreferencesDebugPane.swift`
- Current mitigation: Main logger output is redacted through `Sources/TokenBarCore/Logging/LogRedactor.swift`; debug dumps are explicit user actions rather than background logging.
- Recommendations: Redact raw debug payloads before writing to disk, keep `/tmp/tokenbar-*-probe.txt` outputs out of commits and support tickets by default, and add tests that assert debug formatters do not include bearer tokens, cookies, API keys, raw emails, or full JSON bodies unless a provider-specific diagnostic explicitly requires them.

**Browser cookies and Keychain access can trigger system prompts or expose session material:**
- Risk: Browser cookie import, Keychain credential reads, OAuth credential extraction, and cookie cache migration touch sensitive system stores and can display macOS prompts if a path misses the no-UI guard.
- Files: `Sources/TokenBarCore/KeychainNoUIQuery.swift`, `Sources/TokenBarCore/KeychainAccessPreflight.swift`, `Sources/TokenBarCore/KeychainAccessGate.swift`, `Sources/TokenBarCore/BrowserCookieAccessGate.swift`, `Sources/TokenBarCore/CookieHeaderCache.swift`, `Sources/TokenBar/CookieHeaderStore.swift`, `Sources/TokenBarCore/KeychainCacheStore.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift`, `.agents/skills/qa-test/SKILL.md`
- Current mitigation: Keychain queries use `KeychainNoUIQuery`; cookie imports use `BrowserCookieAccessGate` cooldowns; raw cookie headers are cached in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; tests use overrides and test stores.
- Recommendations: Any new Keychain or browser-cookie path must use `KeychainNoUIQuery`, `BrowserCookieAccessGate`, `CookieHeaderCache`, or a test store. Do not run live provider probes, browser-cookie imports, real SecItem reads, or `tokenbar usage` against real accounts without explicit user approval.

**Unauthenticated localhost HTTP server exposes usage and cost data to local processes:**
- Risk: `tokenbar serve` returns `/usage` and `/cost` JSON over loopback without a request token, so any process on the same machine can query it while it is running.
- Files: `Sources/TokenBarCLI/CLILocalHTTPServer.swift`, `Sources/TokenBarCLI/CLIServeCommand.swift`, `Tests/TokenBarTests/CLIServeRouterTests.swift`
- Current mitigation: The server binds to `127.0.0.1`, validates the Host header for loopback names, enforces a 16 KB header cap, uses a 5 second request read timeout, and only accepts `GET` routes.
- Recommendations: Keep the bind address loopback-only. Add a random bearer token, Unix socket mode, or explicit opt-in before using this server for long-running integrations. Add origin/CORS tests if browser-facing access is introduced.

**Provider endpoint overrides must stay on the shared security path:**
- Risk: Provider-specific endpoint overrides can become SSRF, credential exfiltration, or downgrade vectors if a fetcher bypasses HTTPS, same-origin redirect, userinfo, host delimiter, and provider-owned-host validation.
- Files: `Sources/TokenBarCore/ProviderHTTPClient.swift`, `Sources/TokenBarCore/ProviderEndpointOverrideValidator.swift`, `Tests/TokenBarTests/ProviderHTTPClientTests.swift`, `Tests/TokenBarTests/ProviderEndpointOverrideSecurityTests.swift`
- Current mitigation: `ProviderHTTPClient` blocks non-HTTPS and cross-origin redirects; `ProviderEndpointOverrideValidator` rejects insecure/userinfo/encoded delimiter cases and supports provider-owned-only policies.
- Recommendations: New fetchers and endpoint overrides must use `ProviderHTTPClient` and `ProviderEndpointOverrideValidator`. Add provider-specific endpoint security tests at the same time as any new override setting.

**Release secrets are environment-driven:**
- Risk: Notarization and Sparkle signing depend on environment variables and key files, including `.mac-release.env` and `SPARKLE_PRIVATE_KEY_FILE`; accidental key-file selection breaks update verification or leaks signing material.
- Files: `.mac-release.env`, `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, `Scripts/verify_appcast.sh`, `docs/RELEASING.md`, `docs/sparkle.md`, `AGENTS.md`
- Current mitigation: Release scripts validate required env vars, copy App Store Connect key material into a `chmod 700` temp directory, validate the Sparkle key file shape, and remove temporary key material on exit.
- Recommendations: Never print or commit release key contents. Use `.mac-release.env` only as a secret-backed environment source, keep release scripts in the foreground, and verify `appcast.xml` signatures before pushing release metadata.

## Performance Bottlenecks

**Local cost usage scans can run for minutes on large archives:**
- Problem: Cost usage scans parse local Codex/Claude/Vertex/Bedrock histories, including recursive Codex session archives, parent/fork session metadata, cache invalidation fingerprints, and pricing refresh state.
- Files: `Sources/TokenBarCore/CostUsageFetcher.swift`, `Sources/TokenBarCore/CostUsageScanExecutor.swift`, `Sources/TokenBarCore/Vendored/CostUsage/CostUsageScanner.swift`, `Sources/TokenBarCore/Vendored/CostUsage/CostUsageCache.swift`, `Sources/TokenBar/UsageStore+TokenCost.swift`, `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift`
- Cause: Codex scans are uncapped; the deprecated automatic byte limit is ignored. The scanner walks local session directories and reads/parses JSONL histories.
- Improvement path: Keep scans on `CostUsageScanExecutor`; do not call scanner parsing directly from the Swift cooperative pool or main actor. Refresh `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift` with `Scripts/regenerate-codex-parser-hash.sh` whenever Codex parsing changes so caches invalidate intentionally.

**OpenAI dashboard WebKit scraping is inherently latency-sensitive:**
- Problem: Codex web usage relies on browser-cookie import, WebKit session validation, offscreen web views, SPA polling, API preflight, cached website data stores, and debug HTML capture.
- Files: `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardBrowserCookieImporter.swift`, `Sources/TokenBarCore/Providers/Codex/CodexWebDashboardStrategy.swift`, `Sources/TokenBar/UsageStore+OpenAIWeb.swift`, `Tests/TokenBarTests/OpenAIDashboardWebViewCacheTests.swift`
- Cause: The data source is a private web dashboard flow rather than a stable public API, so delays, redirects, login walls, Cloudflare pages, and workspace changes affect runtime.
- Improvement path: Keep dashboard parsing and session selection isolated from menu rendering. Extend parser/state tests for new dashboard states, and reserve live WebKit/browser-cookie QA for explicit manual validation.

**Menu rebuild scheduling is sensitive to refresh frequency:**
- Problem: Open-menu refresh, closed-menu preparation, readiness signatures, switcher state, and provider token refreshes can trigger repeated AppKit/SwiftUI rebuild work.
- Files: `Sources/TokenBar/StatusItemController+MenuRefreshScheduling.swift`, `Sources/TokenBar/StatusItemController+MenuTracking.swift`, `Sources/TokenBar/StatusItemController+Menu.swift`, `Sources/TokenBar/MenuDescriptor.swift`, `Tests/TokenBarTests/StatusMenuOpenRefreshTests.swift`, `Tests/TokenBarTests/StatusMenuClosedPreparationTests.swift`, `Tests/TokenBarTests/BatteryDrainDiagnosticTests.swift`
- Cause: The menu reflects many provider states and must avoid stale UI while preventing closed-menu prewarming from freezing the background on every store tick.
- Improvement path: Preserve signature-based short-circuiting and closed-menu deferral. Add tests around rebuild count, baseline refresh, and provider readiness whenever changing observation inputs.

**Subprocess and shell lookup paths can stall if new code bypasses existing runners:**
- Problem: CLI integrations execute external tools from GUI app contexts with non-interactive shell environments, custom PATHs, alias fallbacks, and command timeouts.
- Files: `Sources/TokenBarCore/PathEnvironment.swift`, `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeUsageFetcher.swift`, `Sources/TokenBarCore/Providers/Gemini/GeminiUsageFetcher.swift`, `Sources/TokenBarCore/Providers/Grok/GrokUsageFetcher.swift`
- Cause: Shell init scripts can write enough output to fill pipes, spawn background children, or hang on interactive assumptions.
- Improvement path: Launch CLI tools through the existing binary locator and runners, keep timeouts finite, drain stdout/stderr off the cooperative pool, and terminate process groups on cancellation.

## Fragile Areas

**Status menu AppKit/SwiftUI lifecycle:**
- Files: `Sources/TokenBar/StatusItemController.swift`, `Sources/TokenBar/StatusItemController+Menu.swift`, `Sources/TokenBar/StatusItemController+SwitcherViews.swift`, `Sources/TokenBar/MenuDescriptor.swift`
- Why fragile: The controller holds many task dictionaries, status item references, hosting views, rebuild tokens, and static test switches. It also contains test-specific bypasses for SwiftPM AppKit crashes.
- Safe modification: Prefer descriptor/model seams over live AppKit flows. Always add focused tests in `Tests/TokenBarTests/StatusMenu*Tests.swift` or `Tests/TokenBarTests/MenuCardModelTests.swift` for menu refresh, split/merged state, switcher behavior, and lifecycle changes.
- Test coverage: Broad model and menu tests exist, but live AppKit behavior remains brittle in headless macOS CI.

**OpenAI web usage and cookie import:**
- Files: `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardBrowserCookieImporter.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardWebsiteDataStore.swift`, `Sources/TokenBarCore/Providers/Codex/CodexWebDashboardStrategy.swift`, `Sources/TokenBar/UsageStore+OpenAIWeb.swift`
- Why fragile: The implementation depends on `chatgpt.com` routes, SPA DOM state, cookie source ordering, account/workspace selection, persistent WebKit validation, and fallback trust rules after persistence timeouts.
- Safe modification: Add parser fixtures and importer state tests before touching live fetch behavior. Keep cookie access behind `BrowserCookieAccessGate` and persistent cookie storage behind `CookieHeaderCache`.
- Test coverage: Unit coverage exists for parsers, importers, and WebView cache behavior; live dashboard state requires explicit QA and may drift outside unit-test visibility.

**Claude OAuth credential and delegated refresh flow:**
- Files: `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials+TestingOverrides.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthDelegatedRefreshCoordinator.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeUsageFetcher.swift`, `Sources/TokenBar/UsageStore+ClaudeDebug.swift`
- Why fragile: The flow combines credential files, Keychain reads, CLI availability, OAuth refresh, task-local overrides, nonisolated caches, fingerprint stores, and prompt avoidance.
- Safe modification: Keep real Keychain reads opt-in, use `KeychainNoUIQuery`, add TaskLocal test overrides for every new external dependency, and test both no-prompt and delegated-refresh paths.
- Test coverage: Focused OAuth tests exist, but live Keychain and real CLI auth state are intentionally excluded from normal runs.

**Provider identity and account data siloing:**
- Files: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/Providers/Codex/CodexProviderImplementation.swift`, `Sources/TokenBar/Providers/Claude/ClaudeProviderImplementation.swift`, `Sources/TokenBar/ProviderRegistry.swift`, `Tests/TokenBarTests/CodexAccountMenuDisplaySnapshotTests.swift`, `Tests/TokenBarTests/ProviderSettingsDescriptorTests.swift`
- Why fragile: Multiple providers expose identity, plan, spend, usage, and account-scoped cookie state; cross-provider field reuse can display the wrong identity or plan.
- Safe modification: Keep provider-specific identity and plan fields in provider-owned state. Never render Claude identity/plan fields for Codex or Codex identity/plan fields for Claude.
- Test coverage: Snapshot and descriptor tests cover key display paths; every new account field needs provider-specific display tests.

**Release packaging and appcast flow:**
- Files: `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, `Scripts/package_app.sh`, `Scripts/verify_appcast.sh`, `appcast.xml`, `docs/RELEASING.md`, `docs/releasing-homebrew.md`
- Why fragile: Release builds combine SwiftPM multi-arch builds, dependency resource patching, codesigning, entitlements, notarization, Sparkle appcast generation, GitHub release assets, dSYM merging, and Homebrew instructions.
- Safe modification: Run the documented release scripts in the foreground, verify signatures and `appcast.xml`, and keep generated artifacts out of unrelated edits.
- Test coverage: Swift tests cover install-origin/update-channel logic; shell release scripts depend on local signing tools, GitHub CLI, Sparkle tools, and manual release validation.

**External CLI execution and watchdogs:**
- Files: `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`, `Sources/TokenBarCore/PathEnvironment.swift`, `Sources/TokenBarClaudeWatchdog/main.swift`
- Why fragile: Process groups, PTYs, child cleanup, signal handling, GUI PATH differences, and quarantined binary assessment are platform-sensitive.
- Safe modification: Preserve process-group termination, pipe draining, and finite timeouts. Add cross-platform guards for Linux test targets and macOS-only APIs.
- Test coverage: Process runner and TTY tests exist; GUI-launched environment differences require packaged-app validation when runtime behavior changes.

## Scaling Limits

**Provider matrix grows linearly with each integration:**
- Current capacity: The app defines more than 50 provider cases and mirrored icon/provider descriptors.
- Limit: Each provider adds registry, settings, menu, debug, cache, parser, network, and tests work across multiple files.
- Scaling path: Consolidate provider-owned metadata and actions behind descriptors. Keep shared switches limited to framework-level dispatch and make registry completeness tests fail loudly for missing entries.

**Test suite size is high and concentrated in large files:**
- Current capacity: `Tests/TokenBarTests` contains hundreds of test files, with very large suites such as `Tests/TokenBarTests/CostUsageScannerBreakdownTests.swift`, `Tests/TokenBarTests/MenuCardModelTests.swift`, and `Tests/TokenBarTests/StatusMenuOpenRefreshTests.swift`.
- Limit: Full-suite runs and lint checks become slower, and individual failing tests can require large fixture context.
- Scaling path: Keep new tests focused and colocated with the smallest affected seam. Split large suites only when changing the area, preserving test names and fixture intent.

**Local history scanning has no hard size ceiling for Codex:**
- Current capacity: Codex cost scans are cached and executed on a dedicated serial queue.
- Limit: Very large `~/.codex/sessions` and archived session trees can still produce long scan times and large cache churn.
- Scaling path: Add explicit performance fixtures or benchmark-like tests for large synthetic trees before changing scan traversal, cache fingerprints, or parser hashing.

**Browser-cookie provider flows multiply prompt and cache-state cases:**
- Current capacity: `CookieHeaderCache` supports provider/global and managed-account scopes, Keychain cache migration, and clear-all behavior.
- Limit: Every new cookie-backed provider adds prompt avoidance, cache scope, import failure, refresh, stale-cookie, and logout cleanup cases.
- Scaling path: Reuse the shared cookie cache and browser access gate. Add provider tests that cover cached cookie load, stale cookie clear, refresh/store, and keychain-disabled behavior.

**Local HTTP serve mode has no concurrency policy beyond socket limits:**
- Current capacity: `CLILocalHTTPServer` uses backlog 16, spawns a task per accepted connection, caps request headers at 16 KB, and closes each response.
- Limit: A noisy local client can create repeated `/usage` or `/cost` work while the server is running, even with response caching.
- Scaling path: Add per-route concurrency limits, request authentication, or explicit rate limiting before using serve mode as a shared daemon interface.

## Dependencies at Risk

**SweetCookieKit browser-cookie integration:**
- Risk: Browser cookie access depends on external browser storage formats, macOS permissions, and either a local `../SweetCookieKit` override or the `steipete/SweetCookieKit` package.
- Impact: Cookie import providers can fail or prompt unexpectedly when browser storage formats or permissions change.
- Migration plan: Keep imports behind `BrowserCookieAccessGate`, write parser/importer tests with fixtures, and pin/validate SweetCookieKit behavior before release builds.

**Sparkle and release helper tooling:**
- Risk: Release scripts require Sparkle tools, GitHub CLI, notarization credentials, `appcast.xml` signing, and helper scripts under `$HOME/Projects/agent-scripts`.
- Impact: Missing or mismatched tooling can produce unsigned, unnotarized, or unverifiable update artifacts.
- Migration plan: Keep `Scripts/verify_appcast.sh` and `Scripts/check-release-assets.sh` in the release flow. Document tool requirements in `docs/RELEASING.md`, `docs/sparkle.md`, and `docs/releasing-homebrew.md`.

**KeyboardShortcuts package patching during packaging:**
- Risk: `Scripts/package_app.sh` mutates the SwiftPM checkout for `KeyboardShortcuts` resource bundle lookup before packaging.
- Impact: Upstream changes to `KeyboardShortcuts` can break the patch marker or silently change resource lookup behavior.
- Migration plan: Prefer an upstream fix or a local wrapper only when the package changes. Keep packaging validation around keyboard shortcut resources after dependency updates.

**Pinned Vortex revision and semver dependencies:**
- Risk: `Package.swift` pins `Vortex` to a specific revision and accepts semver updates for Sparkle, Commander, swift-crypto, swift-log, swift-syntax, KeyboardShortcuts, and SweetCookieKit.
- Impact: A package resolution change can affect UI animation, updater behavior, macro compilation, browser cookie access, or Swift 6 strict concurrency warnings.
- Migration plan: Review `Package.resolved` diffs with dependency updates, run `swift test`, `make check`, packaging, and any affected UI/runtime validation.

**External provider CLIs and private web/API endpoints:**
- Risk: Provider behavior depends on local CLIs (`codex`, `claude`, `gemini`, `grok`, `aws`, `auggie`) and private or semi-private web/API endpoints.
- Impact: Provider parsing and status probes can break when CLI output, dashboard routes, auth flows, or API response shapes change.
- Migration plan: Keep provider parser tests fixture-based, add changelog/update links where available, and treat live provider QA as explicit validation rather than routine automated checks.

## Missing Critical Features

**Redacted diagnostic export:**
- Problem: Existing config dump and debug dump paths are useful for support but can include secrets or private account data.
- Blocks: Safe sharing of diagnostics from `Sources/TokenBarCLI/CLIConfigCommand.swift`, `Sources/TokenBar/UsageStore.swift`, and provider debug probes.
- Fix approach: Add a redacted export command that combines config shape, provider enablement, path discovery, cache status, and recent redacted errors without raw tokens, cookies, emails, or full JSON/HTML bodies.

**Authentication for serve mode:**
- Problem: `tokenbar serve` has no per-request secret.
- Blocks: Safe long-running use by browser dashboards, local automations, or multi-user machines.
- Fix approach: Add an opt-in token, Unix-domain socket mode, or generated random local credential surfaced only to the invoking process.

**Provider debug logs for many providers:**
- Problem: `UsageStore.debugLog(for:)` returns placeholder "debug log not yet implemented" strings for many provider cases.
- Blocks: Consistent support workflows and provider-specific troubleshooting.
- Fix approach: Add provider-owned debug formatters with redaction tests and avoid raw API payload passthrough.

**Performance budget tests for local scans and menu rebuilds:**
- Problem: Cost scanning and menu refresh have functional tests but no explicit performance thresholds in the normal suite.
- Blocks: Detecting slow regressions before users with large session archives or many enabled providers notice latency.
- Fix approach: Add deterministic synthetic fixtures and lightweight budget assertions for scan traversal, cache reuse, and menu rebuild counts.

**Release script dry-run validation:**
- Problem: Release scripts perform real signing, notarization, tagging, pushing, and GitHub release creation.
- Blocks: Safe CI-like validation of release script wiring without credentials or external side effects.
- Fix approach: Add dry-run modes or shellcheck-style validation around `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, and `Scripts/make_appcast.sh` that validate inputs, artifact names, appcast metadata, and command availability without using secrets.

## Test Coverage Gaps

**Live Keychain, browser-cookie, and provider-account flows:**
- What's not tested: Real Keychain prompts, browser cookie database access, real SecItem reads, live provider sessions, and live account usage queries.
- Files: `Sources/TokenBarCore/KeychainNoUIQuery.swift`, `Sources/TokenBarCore/BrowserCookieAccessGate.swift`, `Sources/TokenBarCore/CookieHeaderCache.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardBrowserCookieImporter.swift`, `.agents/skills/qa-test/SKILL.md`
- Risk: Prompt regressions, browser permission changes, and account-specific edge cases can escape unit tests.
- Priority: High

**OpenAI dashboard live DOM/API drift:**
- What's not tested: Real `chatgpt.com` dashboard DOM changes, login walls, Cloudflare states, workspace redirects, and live WebKit persistence timing.
- Files: `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardParser.swift`, `Sources/TokenBarCore/Providers/Codex/CodexWebDashboardStrategy.swift`, `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`, `Tests/TokenBarTests/OpenAIDashboardScrapeScriptTests.swift`
- Risk: Parser tests can pass while the live dashboard no longer exposes expected state.
- Priority: High

**Debug dump privacy assertions:**
- What's not tested: A full cross-provider assertion that `dumpLog(toFileFor:)`, `debugRawProbe`, dashboard HTML dumps, and raw JSON debug output exclude secrets and private identifiers.
- Files: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBarCore/Logging/LogRedactor.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/Providers/Augment/AugmentStatusProbe.swift`, `Sources/TokenBarCore/Providers/Cursor/CursorStatusProbe.swift`
- Risk: A support-oriented debug path can leak cookies, API keys, bearer tokens, emails, or raw provider JSON to `/tmp` and then to user-shared logs.
- Priority: High

**Release script dry-run and asset validation:**
- What's not tested: Full release orchestration for `Scripts/release.sh`, notarization setup in `Scripts/sign-and-notarize.sh`, appcast generation in `Scripts/make_appcast.sh`, and GitHub asset checks in `Scripts/check-release-assets.sh` without live credentials.
- Files: `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, `Scripts/check-release-assets.sh`, `Scripts/verify_appcast.sh`, `docs/RELEASING.md`
- Risk: Release failures are discovered during signing, notarization, tag push, appcast generation, or update verification rather than in a safe preflight.
- Priority: Medium

**Provider addition contract tests:**
- What's not tested: A single end-to-end provider contract that verifies every provider has metadata, settings descriptors, implementation spec, debug policy, cache behavior, docs link/changelog policy, and at least one parser/fetcher test.
- Files: `Sources/TokenBarCore/Providers/Providers.swift`, `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`, `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`, `Tests/TokenBarTests/ProviderRegistryTests.swift`, `Tests/TokenBarTests/ProviderSettingsDescriptorTests.swift`
- Risk: Provider additions can satisfy registry completeness while still missing debug, cache, menu, or docs behavior.
- Priority: Medium

**Cost scanner large-archive performance tests:**
- What's not tested: Synthetic multi-root Codex archives large enough to exercise uncapped scan traversal, archive directories, parent/fork metadata, cache fingerprint invalidation, and cancellation timing under load.
- Files: `Sources/TokenBarCore/Vendored/CostUsage/CostUsageScanner.swift`, `Sources/TokenBarCore/CostUsageScanExecutor.swift`, `Sources/TokenBarCore/CostUsageFetcher.swift`, `Tests/TokenBarTests/CostUsageScanExecutorTests.swift`, `Tests/TokenBarTests/CostUsageFetcherTests.swift`
- Risk: Functional correctness remains covered while real-world archives regress scan time or cancellation responsiveness.
- Priority: Medium

**GUI-launched PATH and CLI environment coverage:**
- What's not tested: The exact environment a packaged macOS app sees after Finder/LaunchServices launch, including user shell PATH, Homebrew locations, aliases, quarantined binaries, and app translocation-like cases.
- Files: `Sources/TokenBarCore/PathEnvironment.swift`, `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`, `Scripts/compile_and_run.sh`, `Tests/TokenBarTests/PathEnvironmentTests.swift`
- Risk: CLI integrations can pass Swift tests but fail in the packaged app when PATH or shell state differs.
- Priority: Medium

**Local HTTP serve abuse cases:**
- What's not tested: Sustained concurrent localhost clients, repeated stale-cache fallback behavior under provider timeouts, and any browser-origin behavior if a web UI consumes `tokenbar serve`.
- Files: `Sources/TokenBarCLI/CLILocalHTTPServer.swift`, `Sources/TokenBarCLI/CLIServeCommand.swift`, `Tests/TokenBarTests/CLIServeRouterTests.swift`
- Risk: Long-running serve mode can leak usage/cost data or spend provider refresh budget under local request storms.
- Priority: Medium

---

*Concerns audit: 2026-06-15*
