# Technology Stack

**Analysis Date:** 2026-06-15

## Languages

**Primary:**
- Swift 6.2 - Main application, shared core, CLI, macros, watchdog helper, web probe helper, widget executable, and widget extension code in `Sources/TokenBar`, `Sources/TokenBarCore`, `Sources/TokenBarCLI`, `Sources/TokenBarMacros`, `Sources/TokenBarMacroSupport`, `Sources/TokenBarClaudeWatchdog`, `Sources/TokenBarClaudeWebProbe`, `Sources/TokenBarWidget`, and `WidgetExtension/project.yml`. The package declares `// swift-tools-version: 6.2` in `Package.swift`, and `.swiftformat` pins `--swiftversion 6.2`.

**Secondary:**
- Bash - Build, package, lint, release, appcast, notarization, upstream-review, and live-update scripts in `Scripts/compile_and_run.sh`, `Scripts/package_app.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, `Scripts/release.sh`, `Scripts/lint.sh`, and related files under `Scripts`.
- Python - CI test orchestration and inline release/appcast helpers in `Scripts/ci_swift_test_by_suite.py`, `Scripts/package_app.sh`, `Scripts/make_appcast.sh`, and `Scripts/verify_appcast.sh`.
- JavaScript / Node.js - Documentation generation and listing scripts in `Scripts/docs-list.mjs` and `Scripts/generate-llms.mjs`; npm script wrappers live in `package.json`.
- XML / plist / YAML - macOS bundle metadata, widget-extension project generation, GitHub Actions, SwiftLint, and release/appcast metadata in `WidgetExtension/Info.plist`, `WidgetExtension/project.yml`, `.github/workflows/ci.yml`, `.github/workflows/release-cli.yml`, `.github/workflows/upstream-monitor.yml`, `.swiftlint.yml`, and `appcast.xml`.

## Runtime

**Environment:**
- macOS 14+ menu bar app - Declared in `Package.swift` with `.macOS(.v14)` and in generated bundle metadata in `Scripts/package_app.sh` through `LSMinimumSystemVersion` `14.0`.
- SwiftPM command-line runtime - `TokenBarCLI` is built as a Swift executable target in `Package.swift` and supports macOS plus Linux CLI builds through `.github/workflows/ci.yml` and `.github/workflows/release-cli.yml`.
- WidgetKit app extension - `WidgetExtension/project.yml` builds `TokenBarWidget.appex` as a macOS app-extension target using `SwiftUI.framework`, `WidgetKit.framework`, App Intents from `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`, and shared data from `Sources/TokenBarCore/WidgetSnapshot.swift`.

**Package Manager:**
- Swift Package Manager - `Package.swift` is the source of truth for all Swift targets and products.
- Lockfile: present - `Package.resolved` pins Swift package revisions and versions.
- npm/pnpm wrapper scripts - `package.json` provides script aliases for SwiftPM, lint, docs, and release commands; it does not declare JavaScript package dependencies.

## Frameworks

**Core:**
- SwiftUI - Preferences, menu card views, widgets, and app lifecycle in `Sources/TokenBar/TokenBarApp.swift`, `Sources/TokenBar/PreferencesView.swift`, `Sources/TokenBar/MenuCardView.swift`, and `Sources/TokenBarWidget/*`.
- AppKit - Menu bar status item, menus, windows, icon rendering, login flows, and macOS integration in `Sources/TokenBar/StatusItemController.swift`, `Sources/TokenBar/StatusItemMenu.swift`, `Sources/TokenBar/IconRenderer.swift`, and many `Sources/TokenBar/StatusItemController+*.swift` files.
- Observation - Modern observable state models in `Sources/TokenBar/TokenBarApp.swift`, `Sources/TokenBar/SettingsStore.swift`, and `Sources/TokenBar/UsageStore.swift`.
- WidgetKit / AppIntents - Widget bundle, timelines, switcher intents, and provider/metric configuration in `Sources/TokenBarWidget/TokenBarWidgetBundle.swift` and `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`.
- WebKit - Hidden dashboard scraping, persistent per-account website data stores, and web-session handling in `Sources/TokenBarCore/OpenAIWeb/*`, `Sources/TokenBarCore/WebKit/WebKitTeardown.swift`, and provider web flows such as `Sources/TokenBarCore/Providers/DeepSeek/DeepSeekPlatformTokenManager.swift`.
- Security / LocalAuthentication - Keychain preflight, no-UI reads, cache storage, app group resolution, keychain migration, and prompt gating in `Sources/TokenBarCore/KeychainAccessPreflight.swift`, `Sources/TokenBarCore/KeychainNoUIQuery.swift`, `Sources/TokenBarCore/KeychainCacheStore.swift`, `Sources/TokenBarCore/AppGroupSupport.swift`, and `Sources/TokenBar/KeychainMigration.swift`.
- ServiceManagement - Launch-at-login registration through `SMAppService.mainApp` in `Sources/TokenBar/LaunchAtLoginManager.swift`.
- Foundation / FoundationNetworking / URLSession - Provider HTTP requests through `Sources/TokenBarCore/ProviderHTTPClient.swift` and individual provider fetchers under `Sources/TokenBarCore/Providers/*`.
- Darwin / Glibc / POSIX APIs - PTY, subprocess, socket, process-tree, and CLI serve support in `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`, `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCLI/CLILocalHTTPServer.swift`, and `Sources/TokenBarCore/PathEnvironment.swift`.
- SQLite3 - Local database readers/probes in `Sources/TokenBarCore/Providers/OpenCodeGo/OpenCodeGoLocalUsageReader.swift`, `Sources/TokenBarCore/Providers/Windsurf/WindsurfStatusProbe.swift`, and related tests such as `Tests/TokenBarTests/OpenCodeGoLocalUsageReaderTests.swift`.

**Testing:**
- Swift Testing - Enabled for `TokenBarTests` and `TokenBarLinuxTests` in `Package.swift`; many tests import `Testing` under `Tests/TokenBarTests` and `TestsLinux`.
- XCTest - Used alongside Swift Testing for AppKit or XCTest-specific cases such as `Tests/TokenBarTests/StatusMenuTokenAccountSwitcherTests.swift`.

**Build/Dev:**
- SwiftPM - `swift build`, `swift test`, target definitions, macro targets, and Linux CLI builds are defined by `Package.swift`.
- Xcode / xcodebuild - Required for the widget extension build in `Scripts/package_app.sh` and selected in `.github/workflows/ci.yml` and `.github/workflows/release-cli.yml`.
- XcodeGen - Optional generator for `WidgetExtension/TokenBarWidgetExtension.xcodeproj` from `WidgetExtension/project.yml`; `Scripts/package_app.sh` uses an existing project when `xcodegen` is unavailable.
- SwiftFormat 0.59.1 - Installed into `.build/lint-tools/bin` by `Scripts/install_lint_tools.sh`; settings live in `.swiftformat`.
- SwiftLint 0.63.2 - Installed by `Scripts/install_lint_tools.sh`; strict rules and thresholds live in `.swiftlint.yml`.
- Sparkle command-line tools - `Scripts/make_appcast.sh` requires `generate_appcast`; `docs/RELEASING.md` also references `sign_update` and `generate_keys`.
- macOS release tools - `codesign`, `xcrun notarytool`, `stapler`, `spctl`, `ditto`, `lipo`, `install_name_tool`, `iconutil`, and Xcode `ictool` are used by `Scripts/package_app.sh`, `Scripts/sign-and-notarize.sh`, and `Scripts/build_icon.sh`.
- GitHub CLI - `Scripts/release.sh` and `.github/workflows/release-cli.yml` use `gh` for release asset upload and Homebrew tap workflow dispatch.

## Key Dependencies

**Critical:**
- Sparkle 2.9.1 - In-app update framework for direct signed builds; declared in `Package.swift`, pinned in `Package.resolved`, embedded and signed by `Scripts/package_app.sh`, and configured from `Sources/TokenBar/TokenBarApp.swift`.
- SweetCookieKit 0.4.1 - Browser cookie discovery/decryption layer for Safari, Chromium-family, Firefox, Edge, and provider cookie import; declared in `Package.swift`, optionally replaced by `../SweetCookieKit` when `TOKENBAR_USE_LOCAL_SWEETCOOKIEKIT=1`, and used by `Sources/TokenBarCore/BrowserDetection.swift`, `Sources/TokenBarCore/BrowserCookieAccessGate.swift`, and provider cookie importers under `Sources/TokenBarCore/Providers/*`.
- Commander 0.2.2 - CLI command parser for `TokenBarCLI`; declared in `Package.swift`, pinned in `Package.resolved`, and imported by `Sources/TokenBarCLI/CLIEntry.swift`.
- KeyboardShortcuts 2.4.0 - Global keyboard shortcut support; declared in `Package.swift`, pinned in `Package.resolved`, patched/bundled by `Scripts/package_app.sh`, and used in `Sources/TokenBar/TokenBarApp.swift` and `Sources/TokenBar/KeyboardShortcuts+Names.swift`.
- swift-crypto 3.15.1 - Cryptographic utilities for provider signing and hashing; declared in `Package.swift`, pinned in `Package.resolved`, and used by core provider code such as `Sources/TokenBarCore/Providers/Bedrock/BedrockAWSSigner.swift`.
- swift-log 1.12.0 - Structured logging facade; declared in `Package.swift`, pinned in `Package.resolved`, and wrapped by `Sources/TokenBarCore/Logging/CodexBarLog.swift`.
- swift-syntax 600.0.1 - Macro implementation dependency for `TokenBarMacros`; declared in `Package.swift`, pinned in `Package.resolved`, and used by `Sources/TokenBarMacros`.
- Vortex revision `ef5392088d4aeb255c4eee83157dbdafcd31bf07` - UI effect dependency for the app target; declared in `Package.swift` and pinned in `Package.resolved`.

**Infrastructure:**
- swift-asn1 1.7.0 - Transitive cryptography dependency pinned in `Package.resolved`.
- SwiftPM resource bundles - `Scripts/package_app.sh` copies generated resource bundles such as `KeyboardShortcuts_KeyboardShortcuts.bundle` into `TokenBar.app/Contents/Resources`.
- GitHub Actions - CI, CLI release artifacts, Homebrew tap dispatch, and upstream-monitor automation live in `.github/workflows/ci.yml`, `.github/workflows/release-cli.yml`, and `.github/workflows/upstream-monitor.yml`.
- Local release helper - `Scripts/release.sh` sources `~/Projects/agent-scripts/release/sparkle_lib.sh`; `docs/RELEASING.md` documents `Scripts/mac-release` as the resolver for shared macOS release tooling.

## Configuration

**Environment:**
- Main app/CLI provider config: `~/.tokenbar/config.json`, overrideable by `TOKENBAR_CONFIG`; implementation lives in `Sources/TokenBarCore/Config/CodexBarConfig.swift` and `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`.
- Config permissions: writes are atomic and chmod `0600` on macOS/Linux in `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`.
- Provider config fields: `apiKey`, `managementAPIKey`, `secretKey`, `cookieHeader`, `cookieSource`, `region`, `workspaceID`, `enterpriseHost`, `tokenAccounts`, `awsProfile`, and `awsAuthMode` are modeled in `Sources/TokenBarCore/Config/CodexBarConfig.swift`.
- Provider env projection: saved config is mapped into provider-specific env vars by `Sources/TokenBarCore/Config/ProviderConfigEnvironment.swift`.
- CLI path overrides: local provider tools can be located through `CODEX_CLI_PATH`, `CLAUDE_CLI_PATH`, `GEMINI_CLI_PATH`, `ANTIGRAVITY_CLI_PATH`, `GROK_CLI_PATH`, `AWS_CLI_PATH`, and `AUGGIE_CLI_PATH` in `Sources/TokenBarCore/PathEnvironment.swift`.
- Release environment: `.mac-release.env` exists and is intentionally not read here; `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`, and `Scripts/release.sh` require `APP_STORE_CONNECT_*` variables and `SPARKLE_PRIVATE_KEY_FILE`.
- Version environment: `version.env` exists and is sourced by release/package scripts; it was not read during this mapping.

**Build:**
- Swift package: `Package.swift`, `Package.resolved`.
- Formatting/linting: `.swiftformat`, `.swiftlint.yml`, `Scripts/lint.sh`, `Scripts/install_lint_tools.sh`.
- Script wrappers: `Makefile`, `package.json`.
- App packaging/signing: `Scripts/package_app.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/release.sh`, `Scripts/release_artifacts.sh`.
- Sparkle appcast: `Scripts/make_appcast.sh`, `Scripts/verify_appcast.sh`, `appcast.xml`, `docs/sparkle.md`.
- Widget extension: `WidgetExtension/project.yml`, `WidgetExtension/Info.plist`, `WidgetExtension/TokenBarWidgetExtension.xcodeproj/project.pbxproj`.
- CI/CD: `.github/workflows/ci.yml`, `.github/workflows/release-cli.yml`, `.github/workflows/upstream-monitor.yml`.

## Platform Requirements

**Development:**
- macOS development requires Xcode with Swift 6.2 support; CI selects Xcode 26.1.1, 26.1, or `/Applications/Xcode.app` in `.github/workflows/ci.yml`.
- The app build path expects macOS SDKs, SwiftPM, `xcodebuild`, signing tools, and optional `xcodegen`; see `Scripts/package_app.sh`.
- `make check` runs `Scripts/lint.sh lint`, which verifies `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift`, installs pinned lint tools, runs SwiftFormat in lint mode, and runs SwiftLint strict.
- Linux CLI CI installs Swift 6.2.1 via `swiftly` and builds `TokenBarCLI` with `--static-swift-stdlib` in `.github/workflows/ci.yml`.
- Live provider tests and Keychain/browser-cookie flows require explicit user intent; safe parser/config tests should use stubs and `KeychainNoUIQuery` per `AGENTS.md` and `.agents/skills/qa-test/SKILL.md`.

**Production:**
- Direct app distribution targets macOS 14+ as a signed/notarized LSUIElement app bundle generated by `Scripts/package_app.sh` and `Scripts/sign-and-notarize.sh`.
- Direct updates use Sparkle appcast entries in `appcast.xml` served from GitHub raw URLs and release assets in GitHub Releases; Sparkle is disabled for Homebrew and unsigned/ad-hoc builds in `Sources/TokenBar/TokenBarApp.swift` and `Scripts/package_app.sh`.
- Homebrew distribution uses the `y0shua1ee/homebrew-tokenbar` tap; CLI release tarballs and checksums are built and uploaded by `.github/workflows/release-cli.yml`.
- Standalone CLI distribution targets macOS arm64/x86_64 and Linux x86_64/aarch64 through `.github/workflows/release-cli.yml`.

---

*Stack analysis: 2026-06-15*
