<!-- refreshed: 2026-06-15 -->
# Architecture

**Analysis Date:** 2026-06-15

## System Overview

```text
TokenBar.app
  `Sources/TokenBar/TokenBarApp.swift`
  `Sources/TokenBar/StatusItemController.swift`
  `Sources/TokenBar/PreferencesView.swift`
        |
        v
MainActor observable app state
  `Sources/TokenBar/SettingsStore.swift`
  `Sources/TokenBar/UsageStore.swift`
        |
        v
Provider orchestration
  `Sources/TokenBar/ProviderRegistry.swift`
  `Sources/TokenBar/Providers/Shared/ProviderCatalog.swift`
  `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`
  `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`
        |
        v
Provider integrations and local probes
  `Sources/TokenBarCore/Providers/*`
  `Sources/TokenBarCore/OpenAIWeb/*`
  `Sources/TokenBarCore/Host/*`
        |
        v
Storage, system services, and external surfaces
  `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`
  `Sources/TokenBarCore/AppGroupSupport.swift`
  `Sources/TokenBarCore/KeychainAccessGate.swift`
  `Sources/TokenBarCore/WidgetSnapshot.swift`
  provider CLIs, provider APIs, browser cookies, Keychain, UserDefaults

Other entry surfaces:
  `Sources/TokenBarCLI/CLIEntry.swift`
  `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`
  `Sources/TokenBarClaudeWatchdog/main.swift`
  `Sources/TokenBarClaudeWebProbe/ClaudeWebProbeEntry.swift`
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App entry | Boot logging, Keychain prompt coordination, settings/store construction, Sparkle updater wiring, SwiftUI settings scene. | `Sources/TokenBar/TokenBarApp.swift` |
| App delegate | Owns AppKit lifecycle, creates the status item controller, installs keyboard shortcut, handles shutdown cleanup and weekly-limit reset confetti. | `Sources/TokenBar/TokenBarApp.swift` |
| Status item controller | Owns `NSStatusItem` instances, menu lifecycle, menu refresh scheduling, icons, provider switcher, menu actions, and shutdown cleanup. | `Sources/TokenBar/StatusItemController.swift` |
| Usage store | MainActor observable state for usage snapshots, errors, status probes, token cost snapshots, OpenAI web state, historical data, and widget snapshots. | `Sources/TokenBar/UsageStore.swift` |
| Settings store | MainActor observable settings facade over UserDefaults, app-group defaults, `CodexBarConfig`, provider enablement/order, and provider-specific settings. | `Sources/TokenBar/SettingsStore.swift` |
| Provider registry | Builds per-provider app fetch specs from descriptors, settings snapshots, environment overrides, selected token accounts, and active Codex account routing. | `Sources/TokenBar/ProviderRegistry.swift` |
| Provider descriptors | Core provider metadata, branding, CLI config, token-cost support, and strategy pipelines. | `Sources/TokenBarCore/Providers/ProviderDescriptor.swift` |
| Provider implementations | App-side provider behavior for settings rows, menu entries, source labels, availability, login flow, and optional provider runtimes. | `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift` |
| CLI | Commander-based executable for `usage`, `cost`, `serve`, `config`, `cache`, and `diagnose`. | `Sources/TokenBarCLI/CLIEntry.swift` |
| Widget | WidgetKit timeline providers and intents backed by shared widget snapshots. | `Sources/TokenBarWidget/TokenBarWidgetProvider.swift` |
| Config store | Loads and saves normalized `~/.tokenbar/config.json` or `TOKENBAR_CONFIG` with secure file permissions. | `Sources/TokenBarCore/Config/CodexBarConfigStore.swift` |
| App group support | Resolves app group IDs, shared defaults, widget snapshot locations, and app-group migration. | `Sources/TokenBarCore/AppGroupSupport.swift` |
| Logging | Shared logging bootstrap, OSLog/file/stderr destinations, categories, metadata helpers, and redaction. | `Sources/TokenBarCore/Logging/CodexBarLog.swift` |
| Macro support | Provider descriptor and implementation registration macros. | `Sources/TokenBarMacroSupport/ProviderRegistrationMacros.swift` |
| Release/package scripts | Build, package, sign/notarize, appcast, release, lint, and generated hash checks. | `Scripts/` |

## Pattern Overview

**Overall:** SwiftPM multi-target macOS menu bar app with descriptor-driven providers, MainActor observable state, AppKit status menus, SwiftUI settings/menu cards, and strategy-based fetch pipelines in a shared core library.

**Key Characteristics:**
- Keep provider domain logic in `Sources/TokenBarCore/Providers/<Provider>/` and app-specific UI/settings behavior in `Sources/TokenBar/Providers/<Provider>/`.
- Drive provider fetching through `ProviderDescriptor.fetchPlan` and `ProviderFetchStrategy`; do not call provider fetchers directly from menu or settings UI.
- Keep mutable UI-facing state in `@MainActor @Observable` models: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/SettingsStore.swift`, and `Sources/TokenBar/TokenBarApp.swift`.
- Use `MenuDescriptor` and `ProviderImplementation` descriptor methods to produce app/menu/settings data; the status item controller owns the actual AppKit/SwiftUI rendering.
- Treat credentials as provider-config, Keychain, browser-cookie, or token-account inputs. Do not move secret values into logs, docs, test fixtures, UserDefaults-only storage, or planning files.
- Use `TokenBarCore` for code shared by the app, CLI, widget, and Linux tests.

## Layers

**SwiftUI/AppKit App Shell:**
- Purpose: Boot the macOS app, keep SwiftUI lifecycle alive, expose settings, and delegate AppKit lifecycle work.
- Location: `Sources/TokenBar/TokenBarApp.swift`
- Contains: `TokenBarApp`, `AppDelegate`, updater abstraction, Sparkle integration, app lifecycle wiring.
- Depends on: `AppKit`, `SwiftUI`, `Observation`, `KeyboardShortcuts`, `Sparkle`, `TokenBarCore`.
- Used by: The packaged `TokenBar.app` executable target in `Package.swift`.

**Status Menu UI:**
- Purpose: Render menu bar icons, build `NSMenu` content, host SwiftUI menu cards, schedule open-menu rebuilds, and map menu actions to app behavior.
- Location: `Sources/TokenBar/StatusItemController*.swift`, `Sources/TokenBar/MenuDescriptor.swift`, `Sources/TokenBar/MenuContent.swift`, `Sources/TokenBar/MenuCardView.swift`
- Contains: AppKit menu delegates, menu descriptors, SwiftUI card views, provider switcher views, icon renderers, action mapping.
- Depends on: `UsageStore`, `SettingsStore`, `ProviderCatalog`, `TokenBarCore`.
- Used by: `AppDelegate.ensureStatusController()` in `Sources/TokenBar/TokenBarApp.swift`.

**Observable App State:**
- Purpose: Maintain live state, settings, provider enablement, refresh timers, errors, snapshots, background work, and widget persistence.
- Location: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/UsageStore+*.swift`, `Sources/TokenBar/SettingsStore.swift`, `Sources/TokenBar/SettingsStore+*.swift`
- Contains: `@Observable` stores, observation tokens, provider refresh task coalescing, config persistence, UserDefaults-backed preferences, Keychain-gated settings.
- Depends on: `TokenBarCore`, `ProviderRegistry`, `ProviderCatalog`, app storage helpers.
- Used by: `TokenBarApp`, `StatusItemController`, preferences views, widgets through `WidgetSnapshotStore`.

**App-Side Provider Adapter Layer:**
- Purpose: Convert provider capabilities into menu rows, settings rows, login flows, runtime hooks, availability checks, and source-label decorations.
- Location: `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`, `Sources/TokenBar/Providers/<Provider>/`
- Contains: `ProviderImplementation`, `ProviderImplementationRegistry`, `ProviderCatalog`, provider settings stores, login flows, provider runtimes.
- Depends on: `TokenBarCore`, `SettingsStore`, `UsageStore`, `SwiftUI` bindings where settings UI needs descriptors.
- Used by: `UsageStore`, `MenuDescriptor`, preferences panes, provider runtime actions.

**Core Provider Fetch Layer:**
- Purpose: Define providers, metadata, fetch contexts, fetch strategies, models, status probes, config models, local parsers, HTTP clients, and browser-cookie helpers.
- Location: `Sources/TokenBarCore/Providers/`, `Sources/TokenBarCore/OpenAIWeb/`, `Sources/TokenBarCore/Host/`, `Sources/TokenBarCore/Config/`
- Contains: `UsageProvider`, `ProviderDescriptor`, `ProviderFetchPlan`, `ProviderFetchStrategy`, provider fetchers, provider settings readers, token-account support.
- Depends on: `Foundation`, `FoundationNetworking`, `Security`, `LocalAuthentication`, `SweetCookieKit`, `swift-crypto`, `swift-log`.
- Used by: `Sources/TokenBar`, `Sources/TokenBarCLI`, `Sources/TokenBarWidget`, `TestsLinux`.

**CLI Layer:**
- Purpose: Provide non-UI usage/config/cost/diagnostic commands and a localhost server mode.
- Location: `Sources/TokenBarCLI/`
- Contains: `TokenBarCLI`, `CLIUsageCommand`, `CLIConfigCommand`, `CLICostCommand`, `CLIServeCommand`, command options, output payloads, renderer.
- Depends on: `Commander`, `TokenBarCore`.
- Used by: Packaged helper at `TokenBar.app/Contents/Helpers/TokenBarCLI`, scripts, live QA flows.

**Widget Layer:**
- Purpose: Render WidgetKit timelines from a compact shared snapshot generated by the app.
- Location: `Sources/TokenBarWidget/`, `WidgetExtension/`
- Contains: Widget bundle, intents, timeline providers, widget views, Xcode project metadata.
- Depends on: `WidgetKit`, `AppIntents`, `SwiftUI`, `TokenBarCore`.
- Used by: Widget extension target and shared snapshot file from `WidgetSnapshotStore`.

**Macro and Generated Layer:**
- Purpose: Reduce boilerplate for provider descriptors and registrations; preserve generated parser-hash integrity.
- Location: `Sources/TokenBarMacros/`, `Sources/TokenBarMacroSupport/`, `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift`
- Contains: SwiftSyntax macros and generated hash file.
- Depends on: `swift-syntax` and `Scripts/regenerate-codex-parser-hash.sh`.
- Used by: Provider descriptor/implementation declarations and lint checks.

## Data Flow

### Primary App Refresh Path

1. App boot constructs `SettingsStore`, `UsageStore`, `ManagedCodexAccountCoordinator`, and `CodexAccountPromotionCoordinator` (`Sources/TokenBar/TokenBarApp.swift:19`).
2. `AppDelegate.applicationDidFinishLaunching` creates `StatusItemController` and installs keyboard/menu observers (`Sources/TokenBar/TokenBarApp.swift:381`).
3. `StatusItemController.init` wires observation, creates status items, updates visibility, renders icons, and schedules account revalidation (`Sources/TokenBar/StatusItemController.swift:369`).
4. `UsageStore.init` builds `providerSpecs` from `ProviderRegistry`, hydrates cached state, starts timers, and schedules initial refresh/background work (`Sources/TokenBar/UsageStore.swift:226`).
5. `UsageStore.runRefresh` computes enabled providers, clears disabled/unavailable state, fans out provider refresh/status work with `withTaskGroup`, schedules token-cost and OpenAI web refreshes, and persists the widget snapshot (`Sources/TokenBar/UsageStore.swift:505`).
6. `UsageStore.refreshProvider` coalesces or supersedes per-provider refresh tasks, builds fetch context, runs `ProviderDescriptor.fetchOutcome`, and applies snapshots/errors back on MainActor (`Sources/TokenBar/UsageStore+Refresh.swift:36`).
7. `ProviderDescriptor.fetchOutcome` delegates to the provider's `ProviderFetchPlan` and ordered `ProviderFetchStrategy` pipeline (`Sources/TokenBarCore/Providers/ProviderDescriptor.swift:28`, `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift:191`).
8. Store observation invalidates menus and icons; `StatusItemController` updates persistent rows, icons, and open menus (`Sources/TokenBar/StatusItemController.swift:481`, `Sources/TokenBar/StatusItemController+MenuRefreshScheduling.swift:1`).

### Menu Open Path

1. `StatusItemController.makeMenu` chooses merged-menu or provider-menu construction (`Sources/TokenBar/StatusItemController+Menu.swift:52`).
2. `menuWillOpen` resolves the provider/overview selection, defers OpenAI web refresh while Codex menus are open, revalidates menu data, and schedules open-menu refresh (`Sources/TokenBar/StatusItemController+Menu.swift:59`).
3. `populateMenu` builds `MenuDescriptor`, selects card width, computes switcher/account contexts, and either smart-updates existing menu content or rebuilds menu items (`Sources/TokenBar/StatusItemController+Menu.swift:198`).
4. `MenuDescriptor.build` converts `UsageStore`, `SettingsStore`, and provider implementation hooks into pure menu sections/actions (`Sources/TokenBar/MenuDescriptor.swift:74`).
5. `selector(for:)` maps descriptor actions to Objective-C selectors on `StatusItemController` (`Sources/TokenBar/StatusItemController+MenuActionMapping.swift:4`).

### Manual Refresh Path

1. Menu action `.refresh` maps to `StatusItemController.refreshNow` (`Sources/TokenBar/StatusItemController+Actions.swift:51`).
2. `performStoreRefresh` sets `ProviderInteractionContext` to `.userInitiated`, calls `UsageStore.refresh(forceTokenUsage:)`, then invalidates open menus or all menus (`Sources/TokenBar/StatusItemController+Actions.swift:28`).
3. `UsageStore.runRefresh` refreshes provider usage, status, token cost, credits, OpenAI web state, and widget snapshots (`Sources/TokenBar/UsageStore.swift:505`).

### CLI Usage Path

1. `TokenBarCLI.main` normalizes argv, resolves Commander commands, bootstraps logging, and dispatches command handlers (`Sources/TokenBarCLI/CLIEntry.swift:19`).
2. `runUsage` loads `CodexBarConfig`, resolves provider/account/source options, creates `UsageFetcher`, `ClaudeUsageFetcher`, `BrowserDetection`, and a token-account context (`Sources/TokenBarCLI/CLIUsageCommand.swift:45`).
3. CLI fetches provider output through the same `ProviderDescriptorRegistry` and `ProviderFetchPlan` layer used by the app, with runtime `.cli` and CLI-safe Keychain interaction policy (`Sources/TokenBarCLI/CLIUsageCommand.swift`, `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift:20`).
4. CLI renders text or JSON payloads and exits with typed exit-code categories from `Sources/TokenBarCLI/CLIExitCode.swift`.

### Config Change Path

1. `SettingsStore` loads or migrates `CodexBarConfig` during initialization (`Sources/TokenBar/SettingsStore.swift:176`).
2. Provider order/enablement and provider fields are updated through `updateProviderConfig` or `setProviderOrder` (`Sources/TokenBar/SettingsStore+ConfigPersistence.swift:27`, `Sources/TokenBar/SettingsStore+ConfigPersistence.swift:61`).
3. Config mutations normalize provider order, update cached provider state, debounce persistence, bump `configRevision`, and broadcast `.tokenbarProviderConfigDidChange` for local changes (`Sources/TokenBar/SettingsStore+ConfigPersistence.swift:12`).
4. `CodexBarConfigStore.save` writes normalized JSON atomically and applies `0600` permissions (`Sources/TokenBarCore/Config/CodexBarConfigStore.swift:43`).

### Widget Snapshot Path

1. Refresh completion calls `UsageStore.persistWidgetSnapshot(reason:)` (`Sources/TokenBar/UsageStore+WidgetSnapshot.swift:8`).
2. The app serializes enabled provider entries, rate windows, Codex projections, token cost summaries, and daily usage into `WidgetSnapshot` (`Sources/TokenBarCore/WidgetSnapshot.swift:3`).
3. `WidgetSnapshotStore.save` writes `widget-snapshot.json` into the current app-group container or Application Support fallback (`Sources/TokenBarCore/WidgetSnapshot.swift:153`, `Sources/TokenBarCore/AppGroupSupport.swift:6`).
4. Widget timelines load the snapshot in `TokenBarTimelineProvider` and refresh on a 30-minute policy (`Sources/TokenBarWidget/TokenBarWidgetProvider.swift`).

**State Management:**
- Main UI state uses Swift Observation with `@Observable` classes and `@Bindable` views.
- Long-lived app state lives in `SettingsStore` and `UsageStore`; use their extension files for feature-specific behavior instead of adding unrelated logic to the base files.
- Provider refreshes are asynchronous `Task`/`withTaskGroup` flows that publish final state back on MainActor.
- Open menus are intentionally not rebuilt on every store mutation; use menu invalidation/version/signature helpers in `StatusItemController+MenuRefreshScheduling.swift`.
- Config state is split between `CodexBarConfig` in `~/.tokenbar/config.json`/`TOKENBAR_CONFIG` and UserDefaults-backed display/runtime preferences in `SettingsStore+Defaults.swift`.

## Key Abstractions

**`UsageProvider`:**
- Purpose: Canonical provider enum and provider ordering surface.
- Examples: `Sources/TokenBarCore/Providers/Providers.swift`, `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`
- Pattern: Add providers to `UsageProvider.allCases`, descriptor registry, implementation registry, resources, settings, and tests together.

**`ProviderDescriptor`:**
- Purpose: Core metadata and fetching contract for a provider.
- Examples: `Sources/TokenBarCore/Providers/Codex/CodexProviderDescriptor.swift`, `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIProviderDescriptor.swift`
- Pattern: Define metadata, branding, token-cost support, fetch plan, CLI aliases/version detector, and fetch strategies in `TokenBarCore`.

**`ProviderFetchPlan` and `ProviderFetchStrategy`:**
- Purpose: Ordered, availability-gated fetch pipeline that can fall back between CLI, web, OAuth, API-token, local-probe, or dashboard strategies.
- Examples: `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`, `Sources/TokenBarCore/Providers/Codex/CodexProviderDescriptor.swift`
- Pattern: Strategies return `ProviderFetchResult` and record attempts; strategy fallback is explicit through `shouldFallback(on:context:)`.

**`ProviderImplementation`:**
- Purpose: App-side provider hooks for menu/settings/login/runtime behavior.
- Examples: `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`, `Sources/TokenBar/Providers/Codex/CodexProviderImplementation.swift`
- Pattern: Return descriptors and behavior hooks, not custom ad hoc settings views; keep provider identity fields siloed by provider.

**`ProviderRegistry`:**
- Purpose: Builds app fetch specs from core descriptors, selected token accounts, settings snapshots, active Codex account routing, and environment overrides.
- Examples: `Sources/TokenBar/ProviderRegistry.swift`
- Pattern: Use `ProviderRegistry.makeSettingsSnapshot` and `ProviderRegistry.makeEnvironment` for app fetch context construction.

**`UsageStore`:**
- Purpose: Aggregates provider snapshots, errors, status, costs, account state, runtime state, and refresh scheduling.
- Examples: `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/UsageStore+Refresh.swift`
- Pattern: Add feature-specific store behavior in `UsageStore+Feature.swift`; preserve MainActor state publication and task coalescing.

**`SettingsStore`:**
- Purpose: Central settings/config facade over `CodexBarConfig`, UserDefaults, app-group defaults, Keychain-backed stores, and provider setting projections.
- Examples: `Sources/TokenBar/SettingsStore.swift`, `Sources/TokenBar/SettingsStore+ConfigPersistence.swift`, `Sources/TokenBar/SettingsStore+Defaults.swift`
- Pattern: Use typed properties and provider config mutation helpers; bump config revision through existing persistence paths.

**`MenuDescriptor`:**
- Purpose: Pure, testable menu model for usage sections, account sections, actions, and meta rows.
- Examples: `Sources/TokenBar/MenuDescriptor.swift`, `Tests/TokenBarTests/MenuDescriptor*Tests.swift`
- Pattern: Add menu semantics to `MenuDescriptor` and provider-specific entries through `ProviderImplementation`; keep rendering in `StatusItemController`/menu views.

**`WidgetSnapshot`:**
- Purpose: Compact cross-process snapshot consumed by WidgetKit.
- Examples: `Sources/TokenBarCore/WidgetSnapshot.swift`, `Sources/TokenBar/UsageStore+WidgetSnapshot.swift`
- Pattern: Persist derived, non-secret display data only.

**Keychain and Cookie Gates:**
- Purpose: Prevent unintended macOS prompts, allow process/task-level Keychain disabling, and apply no-UI Keychain queries.
- Examples: `Sources/TokenBarCore/KeychainAccessGate.swift`, `Sources/TokenBarCore/KeychainNoUIQuery.swift`, `Sources/TokenBar/KeychainPromptCoordinator.swift`
- Pattern: Use no-UI preflight/gates for tests, CLI, and background probes; require explicit live validation for prompt-prone flows.

## Entry Points

**Menu Bar App:**
- Location: `Sources/TokenBar/TokenBarApp.swift`
- Triggers: macOS launches `TokenBar.app`.
- Responsibilities: Initialize logging, Keychain prompt coordination, settings, usage store, coordinators, updater, SwiftUI settings scene, and AppKit delegate.

**AppKit Lifecycle:**
- Location: `Sources/TokenBar/TokenBarApp.swift`
- Triggers: `NSApplicationDelegate` callbacks.
- Responsibilities: Status item construction, keyboard shortcut setup, termination cleanup, notification handling.

**CLI:**
- Location: `Sources/TokenBarCLI/CLIEntry.swift`
- Triggers: `TokenBarCLI` executable or packaged helper.
- Responsibilities: Parse commands, load config, run usage/cost/config/diagnose/cache/serve flows, render text/JSON, return exit codes.

**Widget:**
- Location: `Sources/TokenBarWidget/TokenBarWidgetBundle.swift`, `Sources/TokenBarWidget/TokenBarWidgetProvider.swift`
- Triggers: WidgetKit timeline refresh and AppIntent configuration.
- Responsibilities: Load shared snapshot, render provider widgets, save selected provider through shared defaults.

**Claude Watchdog Helper:**
- Location: `Sources/TokenBarClaudeWatchdog/main.swift`
- Triggers: Helper executable target.
- Responsibilities: Process-level watchdog behavior for Claude-related helper state.

**Claude Web Probe Helper:**
- Location: `Sources/TokenBarClaudeWebProbe/ClaudeWebProbeEntry.swift`
- Triggers: Helper executable target.
- Responsibilities: Web probe command-line flow backed by `TokenBarCore`.

**Provider Macro Plugin:**
- Location: `Sources/TokenBarMacros/ProviderRegistrationMacros.swift`
- Triggers: Swift macro expansion during build.
- Responsibilities: Synthesize descriptor properties and provider registration declarations for annotated provider types.

**Build/Release Scripts:**
- Location: `Scripts/compile_and_run.sh`, `Scripts/package_app.sh`, `Scripts/release.sh`, `Scripts/sign-and-notarize.sh`, `Scripts/make_appcast.sh`
- Triggers: Developer/release commands.
- Responsibilities: Build, test, package, sign/notarize, appcast, release, app relaunch, and generated parser hash validation.

## Architectural Constraints

- **Threading:** UI-facing stores and controllers are `@MainActor`. Slow fetch/process/Keychain/browser work must run through async tasks, detached utility work, or provider strategies, then publish final state back on MainActor. Prefer sequential awaits or drained task groups when required and best-effort child work have different failure semantics.
- **Global state:** Static/global state exists in `ProviderDescriptorRegistry`, `ProviderImplementationRegistry`, `CodexBarLog`, `KeychainAccessGate`, `SettingsStore.sharedDefaults`, `TTYCommandRunner`, `BrowserCookieKeychainAccessGate`, and `UserDefaults.standard`. Tests must reset or isolate these through existing test seams.
- **Provider registration:** Provider additions require core enum/descriptor registration in `Sources/TokenBarCore/Providers/Providers.swift` and `Sources/TokenBarCore/Providers/ProviderDescriptor.swift`, plus app implementation registration in `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift`.
- **Credential safety:** `ProviderConfig` includes secret-shaped fields (`apiKey`, `managementAPIKey`, `secretKey`, `cookieHeader`, token accounts). Code and docs may reference these field names and files, but must not read or print user values from `.env*`, `.mac-release.env`, `~/.tokenbar/config.json`, Keychain, browser cookie DBs, or release key files.
- **Keychain prompt safety:** CLI and tests must use `KeychainNoUIQuery`, `KeychainAccessGate`, and explicit prompt-gated flows. Live provider probes, browser-cookie imports, real `SecItem` reads, and packaged app menu QA require explicit user request.
- **Status menu complexity:** `StatusItemController` is split across many extensions. Add new behavior to the nearest focused extension rather than expanding `Sources/TokenBar/StatusItemController.swift`.
- **macOS UI testing:** Prefer stable state/model seams such as `MenuDescriptor`, `ProvidersPane`, `CodexAccountsSectionState`, provider implementations, and store projections over live `NSStatusBar`/`NSMenu` tests unless AppKit wiring is the target.
- **Generated files:** `Sources/TokenBarCore/Generated/CodexParserHash.generated.swift` is generated by `Scripts/regenerate-codex-parser-hash.sh`; edit the vendored cost usage source or run the script, not the generated file by hand.
- **Cross-target sharing:** Code used by app, CLI, widget, or Linux tests belongs in `Sources/TokenBarCore`; app-only UI and AppKit code belongs in `Sources/TokenBar`.
- **Project skills:** Live provider matrix and menu QA instructions live in `.agents/skills/qa-test/SKILL.md`; release/notarization/appcast flow instructions live in `.agents/skills/release-codexbar/SKILL.md`.

## Anti-Patterns

### Bypassing Provider Descriptors

**What happens:** UI, CLI, or store code calls provider-specific fetchers directly instead of going through `ProviderDescriptor.fetchPlan`.
**Why it's wrong:** It loses fetch-attempt tracking, source-mode selection, fallback behavior, runtime differences, token-account overrides, and config snapshots.
**Do this instead:** Add or update a `ProviderFetchStrategy` under `Sources/TokenBarCore/Providers/<Provider>/` and expose it from `<Provider>ProviderDescriptor` in `Sources/TokenBarCore/Providers/<Provider>/`.

### Mixing Provider Identity Fields

**What happens:** A provider menu or usage projection displays email, organization, plan, or login method sourced from another provider.
**Why it's wrong:** Provider data must stay siloed; identity fields have provider-specific authority and privacy boundaries.
**Do this instead:** Use `UsageSnapshot.identity(for:)`, provider-specific projections, and the `ProviderImplementation` rule in `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`.

### Returning Custom Provider Settings Views

**What happens:** A provider implementation injects custom SwiftUI directly into the shared Providers pane.
**Why it's wrong:** The settings pane expects shared descriptors for fields, toggles, actions, pickers, organizations, and token-account visibility.
**Do this instead:** Return descriptor values from `settingsToggles`, `settingsFields`, `settingsActions`, `settingsPickers`, or `settingsOrganizations` in `Sources/TokenBar/Providers/<Provider>/<Provider>ProviderImplementation.swift`.

### Prompt-Prone Validation Without User Request

**What happens:** Tests or ad hoc checks read real Keychain items, browser cookie stores, live account sessions, or real provider dashboards.
**Why it's wrong:** These flows can display macOS Keychain or browser permission prompts and can expose private account state.
**Do this instead:** Use parser tests, stubs, test stores, `KeychainNoUIQuery`, `KeychainAccessGate`, and focused CLI-safe tests in `Tests/TokenBarTests/` unless the user explicitly requests live QA.

### Adding Shared Logic To App-Only Targets

**What happens:** CLI/widget/Linux-needed models or parsers are placed under `Sources/TokenBar`.
**Why it's wrong:** `Sources/TokenBar` depends on AppKit/SwiftUI and is not the shared core consumed by CLI, widget, or Linux tests.
**Do this instead:** Put shared models, parsers, fetchers, and config code under `Sources/TokenBarCore/`; keep AppKit/SwiftUI presentation under `Sources/TokenBar/`.

## Error Handling

**Strategy:** Provider errors are captured per provider, often preserving prior snapshots for transport/timeouts, while config/CLI paths return typed validation or exit-code errors.

**Patterns:**
- Provider fetches return `ProviderFetchOutcome` with `Result<ProviderFetchResult, Error>` plus ordered attempts in `Sources/TokenBarCore/Providers/ProviderFetchPlan.swift`.
- `UsageStore` applies success/failure on MainActor, records attempts, uses failure gates, preserves prior data for transport errors, and posts permission-prompt notifications through `Sources/TokenBar/UsageStore+Refresh.swift`.
- Config validation returns structured `CodexBarConfigIssue` values from `Sources/TokenBarCore/Config/CodexBarConfigValidation.swift`.
- CLI exits through `CLIExitCode` and output preferences in `Sources/TokenBarCLI/CLIExitCode.swift` and `Sources/TokenBarCLI/CLIOutputPreferences.swift`.
- Keychain access failures use no-UI preflight and prompt context helpers in `Sources/TokenBarCore/KeychainAccessPreflight.swift` and `Sources/TokenBar/KeychainPromptCoordinator.swift`.

## Cross-Cutting Concerns

**Logging:** `CodexBarLog` centralizes OSLog/file/stderr/JSON logging, categories, metadata, and redaction in `Sources/TokenBarCore/Logging/`. Bootstrap happens in `Sources/TokenBar/TokenBarApp.swift` and `Sources/TokenBarCLI/CLIEntry.swift`.

**Validation:** Config validation is in `Sources/TokenBarCore/Config/CodexBarConfigValidation.swift`; provider endpoint override security is in `Sources/TokenBarCore/ProviderEndpointOverrideValidator.swift`; tests live under `Tests/TokenBarTests/*Validation*Tests.swift` and provider-specific test files.

**Authentication:** Auth inputs come from provider config, token accounts, OAuth stores, provider CLIs, browser cookies, or Keychain-backed stores. Use `Sources/TokenBarCore/KeychainAccessGate.swift`, `Sources/TokenBarCore/KeychainNoUIQuery.swift`, and provider-specific OAuth/cookie/token stores under `Sources/TokenBarCore/Providers/<Provider>/` and `Sources/TokenBar/`.

**Localization:** App strings live under `Sources/TokenBar/Resources/*.lproj/Localizable.strings`; language selection is applied from `SettingsStore` in `Sources/TokenBar/TokenBarApp.swift`.

**Updates:** Sparkle integration and update availability are isolated behind `UpdaterProviding` in `Sources/TokenBar/TokenBarApp.swift`; release assets/appcast are produced by `Scripts/sign-and-notarize.sh` and `Scripts/make_appcast.sh`.

**Notifications:** App notifications and quota/session reset notifications are coordinated by `Sources/TokenBar/AppNotifications.swift`, `Sources/TokenBar/Notifications+TokenBar.swift`, `Sources/TokenBar/SessionQuotaNotifications.swift`, and quota-warning store logic.

**Provider data storage:** App config is `CodexBarConfig` via `Sources/TokenBarCore/Config/CodexBarConfigStore.swift`; widget snapshots use `Sources/TokenBarCore/WidgetSnapshot.swift`; app-group defaults use `Sources/TokenBarCore/AppGroupSupport.swift`; cost caches use `Sources/TokenBarCore/Vendored/CostUsage/` and `Sources/TokenBarCore/PiSessionCostCache.swift`.

---

*Architecture analysis: 2026-06-15*
