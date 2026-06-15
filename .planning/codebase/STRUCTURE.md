# Codebase Structure

**Analysis Date:** 2026-06-15

## Directory Layout

```text
TokenBar/
|-- Sources/                         # SwiftPM source targets
|   |-- TokenBar/                    # macOS menu bar app, AppKit/SwiftUI UI, app-side providers
|   |-- TokenBarCore/                # Shared models, provider fetchers, config, logging, storage
|   |-- TokenBarCLI/                 # Commander-based CLI executable
|   |-- TokenBarWidget/              # WidgetKit implementation
|   |-- TokenBarClaudeWatchdog/      # Helper executable
|   |-- TokenBarClaudeWebProbe/      # Helper executable
|   |-- TokenBarMacros/              # SwiftSyntax macro plugin
|   `-- TokenBarMacroSupport/        # Public macro declarations
|-- Tests/TokenBarTests/             # macOS Swift Testing/XCTest coverage
|-- TestsLinux/                      # Linux-compatible Swift tests
|-- Scripts/                         # Build, lint, package, release, codegen helpers
|-- WidgetExtension/                 # Xcode project metadata for widget extension
|-- docs/                            # User/developer/provider docs and release docs
|-- bin/                             # CLI install and docs helper scripts
|-- Icon.icon/                       # Icon Composer project assets
|-- .agents/skills/                  # Project-local QA/release skill instructions
|-- .ai/                             # Cross-agent handoff and durable decisions
|-- .planning/codebase/              # Generated GSD codebase maps
|-- Package.swift                    # SwiftPM manifest and target graph
|-- Package.resolved                 # SwiftPM lockfile
|-- Makefile                         # Common build/test/lint/release shortcuts
|-- appcast.xml                      # Sparkle appcast generated during releases
|-- config.example.json              # Example TokenBar config without private values
`-- TokenBar-*-adhoc.zip             # Generated ad hoc release artifacts
```

## Directory Purposes

**`Sources/TokenBar`:**
- Purpose: macOS app target for `TokenBar.app`.
- Contains: App entry, AppKit status item controller, SwiftUI preferences/menu cards, icon renderer, login flows, app-side provider implementations, settings stores, Keychain wrappers, notification logic.
- Key files: `Sources/TokenBar/TokenBarApp.swift`, `Sources/TokenBar/StatusItemController.swift`, `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/SettingsStore.swift`, `Sources/TokenBar/MenuDescriptor.swift`, `Sources/TokenBar/ProviderRegistry.swift`.

**`Sources/TokenBar/Providers`:**
- Purpose: App-side provider adapters.
- Contains: One subdirectory per provider plus shared provider UI/settings/runtime contracts.
- Key files: `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`, `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`, `Sources/TokenBar/Providers/Codex/CodexProviderImplementation.swift`, `Sources/TokenBar/Providers/OpenAI/OpenAIAPIProviderImplementation.swift`.

**`Sources/TokenBar/Resources`:**
- Purpose: Bundled app resources.
- Contains: Provider SVG icons, classic app icon, localized strings.
- Key files: `Sources/TokenBar/Resources/ProviderIcon-codex.svg`, `Sources/TokenBar/Resources/Icon-classic.icns`, `Sources/TokenBar/Resources/en.lproj/Localizable.strings`, `Sources/TokenBar/Resources/zh-Hans.lproj/Localizable.strings`.

**`Sources/TokenBarCore`:**
- Purpose: Shared library target consumed by app, CLI, widget, macOS tests, and Linux tests.
- Contains: Provider models/fetchers, config storage/validation, logging, Keychain gates, browser detection, app-group support, widget snapshot models, HTTP clients, process/PTY helpers, vendored cost scanner.
- Key files: `Sources/TokenBarCore/Providers/Providers.swift`, `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`, `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`, `Sources/TokenBarCore/Config/CodexBarConfig.swift`, `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`, `Sources/TokenBarCore/WidgetSnapshot.swift`.

**`Sources/TokenBarCore/Providers`:**
- Purpose: Core provider definitions and fetch logic.
- Contains: Shared provider contracts plus per-provider descriptor, settings reader, fetcher, parser, status probe, OAuth/cookie/token code.
- Key files: `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`, `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`, `Sources/TokenBarCore/Providers/Codex/CodexProviderDescriptor.swift`, `Sources/TokenBarCore/Providers/Claude/ClaudeProviderDescriptor.swift`, `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIProviderDescriptor.swift`.

**`Sources/TokenBarCore/Config`:**
- Purpose: User config schema, persistence, validation, and provider environment projection.
- Contains: `CodexBarConfig`, `ProviderConfig`, config store, validation, active-source models, environment overrides.
- Key files: `Sources/TokenBarCore/Config/CodexBarConfig.swift`, `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`, `Sources/TokenBarCore/Config/CodexBarConfigValidation.swift`, `Sources/TokenBarCore/Config/ProviderConfigEnvironment.swift`.

**`Sources/TokenBarCore/Logging`:**
- Purpose: Shared logging infrastructure.
- Contains: Log bootstrap, destinations, handlers, categories, metadata helpers, redaction.
- Key files: `Sources/TokenBarCore/Logging/CodexBarLog.swift`, `Sources/TokenBarCore/Logging/LogCategories.swift`, `Sources/TokenBarCore/Logging/LogRedactor.swift`.

**`Sources/TokenBarCore/OpenAIWeb`:**
- Purpose: ChatGPT/OpenAI dashboard web integration for optional Codex extras.
- Contains: Browser cookie importer, dashboard fetcher/parser, navigation delegate, scrape script, WebView cache, website data store.
- Key files: `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardParser.swift`, `Sources/TokenBarCore/OpenAIWeb/OpenAIDashboardBrowserCookieImporter.swift`.

**`Sources/TokenBarCore/Host`:**
- Purpose: Local process and PTY helpers for CLI-backed providers.
- Contains: Subprocess runner and TTY command runner.
- Key files: `Sources/TokenBarCore/Host/Process/SubprocessRunner.swift`, `Sources/TokenBarCore/Host/PTY/TTYCommandRunner.swift`.

**`Sources/TokenBarCore/Vendored`:**
- Purpose: Vendored token/cost scanning implementation.
- Contains: Cost usage scanner, pricing, cache helpers, JSONL readers, generated parser hash dependency inputs.
- Key files: `Sources/TokenBarCore/Vendored/CostUsage/CostUsageScanner.swift`, `Sources/TokenBarCore/Vendored/CostUsage/CostUsagePricing.swift`.

**`Sources/TokenBarCore/Generated`:**
- Purpose: Generated Swift files checked by scripts.
- Contains: Parser hash file.
- Key files: `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift`.

**`Sources/TokenBarCLI`:**
- Purpose: CLI executable target.
- Contains: Command entry, command handlers, options, renderers, JSON payloads, local HTTP server, signal handling.
- Key files: `Sources/TokenBarCLI/CLIEntry.swift`, `Sources/TokenBarCLI/CLIUsageCommand.swift`, `Sources/TokenBarCLI/CLIConfigCommand.swift`, `Sources/TokenBarCLI/CLIServeCommand.swift`, `Sources/TokenBarCLI/CLIDiagnoseCommand.swift`.

**`Sources/TokenBarWidget`:**
- Purpose: SwiftPM widget implementation.
- Contains: Widget bundle, timeline providers, intents, views.
- Key files: `Sources/TokenBarWidget/TokenBarWidgetBundle.swift`, `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`, `Sources/TokenBarWidget/TokenBarWidgetViews.swift`.

**`Sources/TokenBarMacros` and `Sources/TokenBarMacroSupport`:**
- Purpose: Swift macro implementation and exported macro declarations.
- Contains: SwiftSyntax compiler plugin and public macro definitions for provider descriptors/implementations.
- Key files: `Sources/TokenBarMacros/ProviderRegistrationMacros.swift`, `Sources/TokenBarMacroSupport/ProviderRegistrationMacros.swift`.

**`Tests/TokenBarTests`:**
- Purpose: macOS test target for app/core/CLI/widget behavior.
- Contains: Provider tests, parser tests, menu descriptor/controller tests, config tests, Keychain prompt safety tests, widget tests, CLI tests.
- Key files: `Tests/TokenBarTests/CodexBarConfigMigratorTests.swift`, `Tests/TokenBarTests/MenuDescriptorKiloTests.swift`, `Tests/TokenBarTests/CLIConfigCommandTests.swift`, `Tests/TokenBarTests/KeychainNoUIQueryTests.swift`.

**`TestsLinux`:**
- Purpose: Linux-compatible tests for core parsing/platform-gated behavior.
- Contains: Swift tests that avoid AppKit-only surfaces.
- Key files: `TestsLinux/OpenAIDashboardParserLinuxTests.swift`, `TestsLinux/CostUsageScanExecutorLinuxTests.swift`, `TestsLinux/PlatformGatingTests.swift`.

**`Scripts`:**
- Purpose: Developer automation and release tooling.
- Contains: Build/run, package, lint, release, signing/notarization, appcast, generated parser hash, docs generation, changelog validation.
- Key files: `Scripts/compile_and_run.sh`, `Scripts/package_app.sh`, `Scripts/lint.sh`, `Scripts/regenerate-codex-parser-hash.sh`, `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`.

**`docs`:**
- Purpose: User, provider, architecture, release, packaging, widget, keychain, and process documentation.
- Contains: Provider docs, release docs, web docs, screenshots/logos, refactor notes, superpower specs/plans.
- Key files: `docs/RELEASING.md`, `docs/providers.md`, `docs/provider.md`, `docs/refresh-loop.md`, `docs/widgets.md`, `docs/keychain-allow.png`.

**`.agents/skills`:**
- Purpose: Project-local skill instructions for agents.
- Contains: Live QA and release workflows.
- Key files: `.agents/skills/qa-test/SKILL.md`, `.agents/skills/release-codexbar/SKILL.md`.

**`.ai`:**
- Purpose: Cross-agent coordination.
- Contains: Handoff and durable decision log.
- Key files: `.ai/HANDOFF.md`, `.ai/DECISIONS.md`.

## Key File Locations

**Entry Points:**
- `Sources/TokenBar/TokenBarApp.swift`: Main app entry, AppDelegate, updater abstraction, lifecycle wiring.
- `Sources/TokenBarCLI/CLIEntry.swift`: CLI main, command dispatch, logging bootstrap.
- `Sources/TokenBarWidget/TokenBarWidgetBundle.swift`: Widget bundle entry.
- `Sources/TokenBarClaudeWatchdog/main.swift`: Claude watchdog helper entry.
- `Sources/TokenBarClaudeWebProbe/ClaudeWebProbeEntry.swift`: Claude web probe helper entry.
- `Sources/TokenBarMacros/ProviderRegistrationMacros.swift`: Macro plugin entry.

**Configuration:**
- `Package.swift`: Swift tools version, platforms, dependencies, targets, resources.
- `Package.resolved`: SwiftPM dependency lockfile.
- `Makefile`: Build/test/lint/release shortcuts.
- `.swiftformat`: SwiftFormat config.
- `.swiftlint.yml`: SwiftLint config.
- `config.example.json`: Safe example provider config.
- `.mac-release.env`: Sensitive release environment file present; note path only and do not read contents.
- `Sources/TokenBarCore/Config/CodexBarConfig.swift`: Config schema.
- `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`: Config storage path and persistence.
- `Sources/TokenBarCore/Config/CodexBarConfigValidation.swift`: Config validation rules.

**Core Logic:**
- `Sources/TokenBar/UsageStore.swift`: App usage state, refresh setup, provider specs, caches.
- `Sources/TokenBar/UsageStore+Refresh.swift`: Provider refresh orchestration and outcome application.
- `Sources/TokenBar/SettingsStore.swift`: Settings initialization and defaults/config bridge.
- `Sources/TokenBar/SettingsStore+ConfigPersistence.swift`: Config mutations, persistence, revision broadcasting.
- `Sources/TokenBar/ProviderRegistry.swift`: App fetch specs and provider environment/snapshot construction.
- `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`: Core descriptor registry.
- `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`: Fetch context, strategies, pipeline, outcomes.
- `Sources/TokenBarCore/Providers/Providers.swift`: Provider enum and metadata model.

**Menu/UI:**
- `Sources/TokenBar/StatusItemController.swift`: Main status item controller state and initialization.
- `Sources/TokenBar/StatusItemController+Menu.swift`: `NSMenu` construction and menu lifecycle.
- `Sources/TokenBar/StatusItemController+Actions.swift`: Menu action implementations.
- `Sources/TokenBar/StatusItemController+MenuActionMapping.swift`: Descriptor action to selector mapping.
- `Sources/TokenBar/StatusItemController+MenuRefreshScheduling.swift`: Open-menu invalidation/rebuild scheduling.
- `Sources/TokenBar/MenuDescriptor.swift`: Pure menu model.
- `Sources/TokenBar/MenuContent.swift`: SwiftUI menu content renderer and status icon view.
- `Sources/TokenBar/MenuCardView.swift`: SwiftUI menu card UI.
- `Sources/TokenBar/PreferencesView.swift`: Preferences shell.
- `Sources/TokenBar/PreferencesProvidersPane.swift`: Provider settings UI.

**Provider Addition/Behavior:**
- `Sources/TokenBarCore/Providers/<Provider>/<Provider>ProviderDescriptor.swift`: Core provider metadata and fetch plan.
- `Sources/TokenBar/Providers/<Provider>/<Provider>ProviderImplementation.swift`: App-side presentation/settings/menu/login behavior.
- `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`: App-side provider contract.
- `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`: App-side provider registry.
- `Sources/TokenBarCore/Providers/ProviderSettingsSnapshot.swift`: Provider settings snapshot passed into core fetchers.
- `Sources/TokenBarCore/Providers/ProviderCLIConfig.swift`: Provider CLI aliases/version detector config.
- `Sources/TokenBar/Resources/ProviderIcon-<provider>.svg`: Provider icon asset.

**Storage/Security:**
- `Sources/TokenBarCore/AppGroupSupport.swift`: App group and shared defaults resolution.
- `Sources/TokenBarCore/WidgetSnapshot.swift`: Widget snapshot persistence model.
- `Sources/TokenBarCore/KeychainAccessGate.swift`: Process/task/defaults-level Keychain access gate.
- `Sources/TokenBarCore/KeychainNoUIQuery.swift`: No-UI Keychain query policy.
- `Sources/TokenBarCore/KeychainAccessPreflight.swift`: Keychain preflight and prompt context.
- `Sources/TokenBar/KeychainPromptCoordinator.swift`: App prompt presentation for Keychain access.
- `Sources/TokenBar/CookieHeaderStore.swift`: Keychain-backed cookie header store.

**Testing:**
- `Tests/TokenBarTests/`: Primary macOS tests.
- `Tests/TokenBarTests/Fixtures/`: Test fixtures copied as resources.
- `TestsLinux/`: Linux test target.
- `Tests/TokenBarTests/KeychainPromptSafetyAuditTests.swift`: Keychain prompt safety audit.
- `Tests/TokenBarTests/StatusMenuOverviewTests.swift`: Status menu model/controller coverage.
- `Tests/TokenBarTests/CLI*Tests.swift`: CLI behavior coverage.

**Release/Packaging:**
- `Scripts/package_app.sh`: Package app bundle.
- `Scripts/compile_and_run.sh`: Build, test, package, relaunch app for dev loop.
- `Scripts/release.sh`: Release orchestration.
- `Scripts/sign-and-notarize.sh`: Signing/notarization.
- `Scripts/make_appcast.sh`: Sparkle appcast generation.
- `Scripts/check-release-assets.sh`: Release asset validation.
- `docs/RELEASING.md`: Release process reference.
- `appcast.xml`: Sparkle appcast.

## Naming Conventions

**Files:**
- App store extensions: `UsageStore+Feature.swift`, `SettingsStore+Feature.swift`, `StatusItemController+Feature.swift` such as `Sources/TokenBar/UsageStore+Refresh.swift`.
- Provider core files: `<Provider>ProviderDescriptor.swift`, `<Provider>UsageFetcher.swift`, `<Provider>SettingsReader.swift`, `<Provider>StatusProbe.swift` under `Sources/TokenBarCore/Providers/<Provider>/`.
- Provider app files: `<Provider>ProviderImplementation.swift`, `<Provider>SettingsStore.swift`, `<Provider>LoginFlow.swift`, `<Provider>ProviderRuntime.swift` under `Sources/TokenBar/Providers/<Provider>/`.
- SwiftUI views: noun-based view names ending in `View`, `Pane`, `Section`, or `Content`, such as `PreferencesProvidersPane.swift` and `MenuCardView.swift`.
- Tests: `FeatureNameTests.swift` in `Tests/TokenBarTests/` or `TestsLinux/`, such as `CodexDashboardAuthorityTests.swift`.
- Generated files: keep `.generated.swift` suffix, such as `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift`.

**Directories:**
- SwiftPM target directories use target names: `Sources/TokenBar`, `Sources/TokenBarCore`, `Sources/TokenBarCLI`, `Sources/TokenBarWidget`.
- Provider directories use display/provider identifiers in PascalCase: `Sources/TokenBarCore/Providers/Codex`, `Sources/TokenBar/Providers/OpenAI`.
- Shared provider contracts live under `Sources/TokenBar/Providers/Shared`.
- Resources live under `Sources/TokenBar/Resources` with `ProviderIcon-<provider>.svg` naming.
- Localization directories use Apple `.lproj` names: `en.lproj`, `zh-Hans.lproj`, `ja.lproj`.

## Where to Add New Code

**New Provider:**
- Core provider enum: `Sources/TokenBarCore/Providers/Providers.swift`
- Core descriptor and fetch strategies: `Sources/TokenBarCore/Providers/<Provider>/<Provider>ProviderDescriptor.swift`
- Core settings reader/fetcher/parser/status probe: `Sources/TokenBarCore/Providers/<Provider>/`
- App implementation: `Sources/TokenBar/Providers/<Provider>/<Provider>ProviderImplementation.swift`
- App settings/login/runtime helpers: `Sources/TokenBar/Providers/<Provider>/`
- Descriptor registry: `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`
- Implementation registry: `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`
- Icon asset: `Sources/TokenBar/Resources/ProviderIcon-<provider>.svg`
- Tests: `Tests/TokenBarTests/<Provider>*Tests.swift`; use `TestsLinux/<Provider>*Tests.swift` only for AppKit-free core behavior.

**New Provider Fetch Strategy:**
- Implementation: `Sources/TokenBarCore/Providers/<Provider>/`
- Registration/order: `<Provider>ProviderDescriptor.makeDescriptor()` in `Sources/TokenBarCore/Providers/<Provider>/<Provider>ProviderDescriptor.swift`
- Tests: `Tests/TokenBarTests/<Provider>UsageFetcherTests.swift`, `Tests/TokenBarTests/<Provider>*Strategy*Tests.swift`, or parser-specific tests.

**New Menu Behavior:**
- Pure model/action: `Sources/TokenBar/MenuDescriptor.swift`
- AppKit construction/lifecycle: `Sources/TokenBar/StatusItemController+Menu.swift`
- Action implementation: `Sources/TokenBar/StatusItemController+Actions.swift`
- Action mapping: `Sources/TokenBar/StatusItemController+MenuActionMapping.swift`
- Rebuild/refresh timing: `Sources/TokenBar/StatusItemController+MenuRefreshScheduling.swift`
- Tests: Prefer `Tests/TokenBarTests/MenuDescriptor*Tests.swift`, `Tests/TokenBarTests/MenuCardModel*Tests.swift`, or state seams over live `NSStatusBar`.

**New Menu Card/View:**
- Shared card model/helpers: `Sources/TokenBar/StatusItemController+MenuCardModel.swift`, `Sources/TokenBar/MenuCardView.swift`, `Sources/TokenBar/MenuCardView+ModelHelpers.swift`
- Provider-specific card extension: `Sources/TokenBar/MenuCardView+<Provider>.swift`
- Chart/storage cards: follow `Sources/TokenBar/*ChartMenuView.swift` and `Sources/TokenBar/StorageBreakdownMenuView.swift`.

**New Preferences Control:**
- General/display/debug/about panes: `Sources/TokenBar/PreferencesGeneralPane.swift`, `Sources/TokenBar/PreferencesDisplayPane.swift`, `Sources/TokenBar/PreferencesDebugPane.swift`, `Sources/TokenBar/PreferencesAboutPane.swift`
- Provider-specific controls: return descriptors from `Sources/TokenBar/Providers/<Provider>/<Provider>ProviderImplementation.swift`
- Shared descriptor row renderers: `Sources/TokenBar/PreferencesProviderSettingsRows.swift`, `Sources/TokenBar/Providers/Shared/ProviderSettingsDescriptors.swift`
- Settings persistence: `Sources/TokenBar/SettingsStore+Defaults.swift` for UserDefaults-backed display/runtime preferences, or `Sources/TokenBarCore/Config/CodexBarConfig.swift` plus `Sources/TokenBar/SettingsStore+Config.swift` for provider config.

**New Config Field:**
- Schema: `Sources/TokenBarCore/Config/CodexBarConfig.swift`
- Validation: `Sources/TokenBarCore/Config/CodexBarConfigValidation.swift`
- Environment projection: `Sources/TokenBarCore/Config/ProviderConfigEnvironment.swift`
- Settings facade: `Sources/TokenBar/SettingsStore+Config.swift` or provider-specific settings store under `Sources/TokenBar/Providers/<Provider>/`
- CLI behavior: `Sources/TokenBarCLI/CLIConfigCommand.swift` if the field needs command support.
- Tests: `Tests/TokenBarTests/ConfigValidationTests.swift`, provider settings tests, CLI config tests.

**New CLI Command:**
- Command descriptor/dispatch: `Sources/TokenBarCLI/CLIEntry.swift`
- Command implementation: `Sources/TokenBarCLI/CLI<Command>Command.swift`
- Options/payloads/rendering: `Sources/TokenBarCLI/CLIOptions.swift`, `Sources/TokenBarCLI/CLIPayloads.swift`, `Sources/TokenBarCLI/CLIRenderer.swift`
- Tests: `Tests/TokenBarTests/CLI<Command>Tests.swift`.

**New Widget Data:**
- Shared model: `Sources/TokenBarCore/WidgetSnapshot.swift`
- Snapshot producer: `Sources/TokenBar/UsageStore+WidgetSnapshot.swift`
- Widget UI/provider: `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`, `Sources/TokenBarWidget/TokenBarWidgetViews.swift`
- App group path/defaults: `Sources/TokenBarCore/AppGroupSupport.swift`
- Xcode project metadata: `WidgetExtension/project.yml`, `WidgetExtension/TokenBarWidgetExtension.xcodeproj/`.

**New Shared Utility:**
- Cross-target models/parsers/helpers: `Sources/TokenBarCore/`
- App-only AppKit/SwiftUI helpers: `Sources/TokenBar/`
- CLI-only helpers: `Sources/TokenBarCLI/`
- Provider-specific shared helpers: `Sources/TokenBarCore/Providers/<Provider>/`

**New Tests:**
- App/core/CLI/widget tests: `Tests/TokenBarTests/<Feature>Tests.swift`
- Linux-compatible core tests: `TestsLinux/<Feature>LinuxTests.swift`
- Fixtures: `Tests/TokenBarTests/Fixtures/`
- Prompt-prone tests: use `KeychainNoUIQuery`, fake stores, parser fixtures, or environment/config stubs instead of live Keychain/browser/account reads.

**New Script or Release Helper:**
- Developer/release script: `Scripts/`
- Make shortcut: `Makefile`
- Release docs: `docs/RELEASING.md` or `docs/releasing-homebrew.md`
- Generated parser hash update: use `Scripts/regenerate-codex-parser-hash.sh`.

**New Documentation:**
- User/provider docs: `docs/<provider>.md` or `docs/<topic>.md`
- Release/process docs: `docs/RELEASING.md`, `docs/packaging.md`, `docs/sparkle.md`
- GSD codebase maps: `.planning/codebase/`
- Cross-agent handoff: `.ai/HANDOFF.md` after non-trivial coding sessions only.

## Special Directories

**`.agents/skills`:**
- Purpose: Project-local instructions for live QA and release work.
- Generated: No
- Committed: Yes

**`.ai`:**
- Purpose: Cross-agent handoff and durable decisions.
- Generated: No
- Committed: Yes

**`.planning/codebase`:**
- Purpose: Generated codebase maps consumed by GSD planning/execution commands.
- Generated: Yes
- Committed: No

**`Sources/TokenBarCore/Generated`:**
- Purpose: Generated Swift source checked by lint.
- Generated: Yes
- Committed: Yes

**`Sources/TokenBarCore/Vendored/CostUsage`:**
- Purpose: Vendored cost usage scanner and pricing code.
- Generated: No
- Committed: Yes

**`WidgetExtension`:**
- Purpose: Widget extension Xcode project metadata outside SwiftPM target sources.
- Generated: Partly
- Committed: Yes

**`Icon.icon`:**
- Purpose: Icon Composer project assets for app icon generation.
- Generated: No
- Committed: Yes

**`TokenBar.app`:**
- Purpose: Locally packaged app bundle.
- Generated: Yes
- Committed: No

**`TokenBar-*-adhoc.zip`:**
- Purpose: Locally generated ad hoc package artifacts.
- Generated: Yes
- Committed: No

**`appcast.xml`:**
- Purpose: Sparkle update feed generated during releases.
- Generated: Yes
- Committed: Yes

**`.mac-release.env`:**
- Purpose: Sensitive release environment file path.
- Generated: No
- Committed: No
- Handling: Do not read, quote, copy, or include values from this file.

---

*Structure analysis: 2026-06-15*
