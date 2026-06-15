# Coding Conventions

**Analysis Date:** 2026-06-15

## Naming Patterns

**Files:**
- Use target-oriented Swift module roots:
  - App UI and app state: `Sources/TokenBar`
  - Shared provider/core logic: `Sources/TokenBarCore`
  - CLI command surface: `Sources/TokenBarCLI`
  - Widget code: `Sources/TokenBarWidget`
- Use `Type+Concern.swift` extension files for large app types and feature slices:
  - `Sources/TokenBar/UsageStore+Refresh.swift`
  - `Sources/TokenBar/UsageStore+TokenAccounts.swift`
  - `Sources/TokenBar/StatusItemController+Menu.swift`
  - `Sources/TokenBar/StatusItemController+MenuTracking.swift`
  - `Sources/TokenBar/MenuCardView+Costs.swift`
- Use provider-specific directories and file names under both core and app modules:
  - Core descriptor: `Sources/TokenBarCore/Providers/Moonshot/MoonshotProviderDescriptor.swift`
  - Core fetcher: `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
  - Core settings reader: `Sources/TokenBarCore/Providers/Moonshot/MoonshotSettingsReader.swift`
  - App implementation: `Sources/TokenBar/Providers/Moonshot/MoonshotProviderImplementation.swift`
  - App settings bridge: `Sources/TokenBar/Providers/Moonshot/MoonshotSettingsStore.swift`
- Use `*Tests.swift` for test suites and `*TestSupport.swift` / `TestStores.swift` for test helpers:
  - `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`
  - `Tests/TokenBarTests/TestStores.swift`

**Functions:**
- Use lower camel case for production functions and computed properties:
  - `fetchUsage(...)` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
  - `moonshotSettingsSnapshot()` in `Sources/TokenBar/Providers/Moonshot/MoonshotSettingsStore.swift`
  - `enabledProvidersOrdered(metadataByProvider:)` in `Sources/TokenBar/SettingsStore.swift`
- Use `_parse...ForTesting`, `_test_...`, and `with...OverrideForTesting` for test-only seams:
  - `_parseSummaryForTesting(_:)` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
  - `_test_settingsPickers(for:)` in `Sources/TokenBar/PreferencesProvidersPane+Testing.swift`
  - `withCredentialsURLOverrideForTesting(...)` call sites in `Tests/TokenBarTests/ClaudeOAuthCredentialsStoreTests.swift`
- Use backtick sentence-style names for Swift Testing test methods:
  - ``func `parses signed in email from client bootstrap HTML`()`` in `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - ``func `admin usage retries transient completions failure once`()`` in `Tests/TokenBarTests/OpenAIAPIUsageFetcherTests.swift`

**Variables:**
- Use lower camel case and prefer descriptive names over abbreviations:
  - `providerRefreshTasks`, `providerAvailabilityCache`, `openAIDashboardRefreshTask` in `Sources/TokenBar/UsageStore.swift`
  - `requestContext`, `retryPolicy`, `historyDays` in `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIUsageFetcher.swift`
- Use `_test_` prefixes only for explicit test hooks on production types:
  - `_test_openAIDashboardLoaderOverride` in `Sources/TokenBar/UsageStore.swift`
  - `_test_codexAccountSnapshotLoader` in `Sources/TokenBar/SettingsStore.swift`
- Use `Noop*`, `InMemory*`, `Stub*`, `Fake*`, `Recording*`, and `Blocking*` prefixes for test doubles:
  - `NoopZaiTokenStore` in `Tests/TokenBarTests/ZaiTokenStoreTestSupport.swift`
  - `InMemoryTokenAccountStore` in `Tests/TokenBarTests/TestStores.swift`
  - `ProviderHTTPTransportStub` in `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`
  - `CoalescingManagedOpenAIDashboardLoader` in `Tests/TokenBarTests/CodexManagedOpenAIWebTestSupport.swift`

**Types:**
- Use PascalCase for types and suffix types by role:
  - `*ProviderDescriptor` for core provider registration, for example `MoonshotProviderDescriptor` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotProviderDescriptor.swift`
  - `*UsageFetcher` for provider usage fetchers, for example `MoonshotUsageFetcher` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
  - `*SettingsReader` for environment/config readers, for example `MoonshotSettingsReader` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotSettingsReader.swift`
  - `*ProviderImplementation` for app-side provider presentation/settings hooks, for example `MoonshotProviderImplementation` in `Sources/TokenBar/Providers/Moonshot/MoonshotProviderImplementation.swift`
  - `*Snapshot`, `*Summary`, `*Context`, `*Descriptor`, `*Payload`, and `*Result` for structured data models.
- Keep shared enum cases lower camel case and stable because they are serialized:
  - `UsageProvider` in `Sources/TokenBarCore/Providers/Providers.swift`
  - `IconStyle` in `Sources/TokenBarCore/Providers/Providers.swift`
  - `RefreshFrequency` in `Sources/TokenBar/SettingsStore.swift`

## Code Style

**Formatting:**
- Use SwiftFormat through `Scripts/lint.sh` and `Scripts/install_lint_tools.sh`.
- Pinned formatting tool: SwiftFormat `0.59.1` in `Scripts/install_lint_tools.sh`.
- Key settings from `.swiftformat`:
  - Swift version `6.2`.
  - 4-space indentation.
  - LF line endings.
  - Maximum width `120`.
  - Explicit `self` is inserted and required; do not remove it.
  - `@testable` imports are grouped at the bottom.
  - Types and extensions get `MARK` organization.
  - Argument, parameter, and collection wrapping uses `before-first`.
- Run `./Scripts/lint.sh format` or `make format` for formatting.
- `Sources/TokenBarCore/Providers/Providers.swift` uses a scoped `swiftformat:disable sortDeclarations` around provider enum ordering; keep such disables narrow and paired with a re-enable.

**Linting:**
- Use SwiftLint through `Scripts/lint.sh`.
- Pinned lint tool: SwiftLint `0.63.2` in `Scripts/install_lint_tools.sh`.
- `make check` and `make lint` both run `./Scripts/lint.sh lint` from `Makefile`.
- `Scripts/lint.sh lint` first runs `Scripts/regenerate-codex-parser-hash.sh --check`, then SwiftFormat lint and SwiftLint strict mode.
- Key rules from `.swiftlint.yml`:
  - Included paths: `Sources`, `Tests`.
  - Generated and resource paths are excluded with patterns such as `**/Generated` and `**/Resources`.
  - Analyzer rules include `unused_declaration` and `unused_import`.
  - `force_cast` and `force_try` are warnings.
  - `function_body_length` warns at `150`, errors at `300`.
  - `file_length` warns at `1500`, errors at `2500`.
  - `type_body_length` warns at `800`, errors at `1200`.
  - `cyclomatic_complexity` warns at `20`, errors at `120`.
  - `line_length` warns at `120`, errors at `250`.
- Keep files below lint thresholds when adding behavior. Prefer extension files such as `UsageStore+Refresh.swift` over growing `UsageStore.swift` for separate concerns.

## Import Organization

**Order:**
1. Apple/system and standard library modules, sorted alphabetically where practical:
   - `import AppKit`
   - `import Foundation`
   - `import Observation`
   - `import SwiftUI`
2. Third-party or package modules:
   - `import Logging` in `Sources/TokenBarCore/Logging/CodexBarLog.swift`
   - `import SweetCookieKit` in `Sources/TokenBar/UsageStore.swift`
   - `import KeyboardShortcuts` in `Sources/TokenBar/TokenBarApp.swift`
3. Project modules:
   - `import TokenBarCore`
   - `import TokenBarMacroSupport`
4. Conditional imports stay directly after the base import they complement:
   - `#if canImport(FoundationNetworking)` blocks in provider fetchers such as `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
   - `#if canImport(Sparkle) && ENABLE_SPARKLE` in `Sources/TokenBar/TokenBarApp.swift`
5. Test-only `@testable` imports go after normal imports:
   - `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
   - `Tests/TokenBarTests/OpenAIAPIUsageFetcherTests.swift`

**Path Aliases:**
- No custom Swift import path aliases are configured in `Package.swift`.
- Use SwiftPM target imports:
  - `TokenBarCore`
  - `TokenBar`
  - `TokenBarCLI`
  - `TokenBarWidget`
  - `TokenBarMacroSupport`
  - `TokenBarMacros`

## Error Handling

**Patterns:**
- Use typed errors that conform to `LocalizedError`; add `Sendable` for async/concurrency-facing errors and `Equatable` when tests assert exact cases:
  - `OpenAIAPIUsageError` in `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIUsageFetcher.swift`
  - `MoonshotUsageError` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
  - `MistralUsageError` in `Sources/TokenBarCore/Providers/Mistral/MistralErrors.swift`
- Provider fetchers should separate error categories:
  - Missing credentials.
  - Network/transport failure.
  - Non-2xx provider API response.
  - Parse or decoding failure.
- Wrap transport failures at provider boundaries when the UI/CLI needs provider-specific copy:
  - `OpenAIAPIUsageFetcher.fetchData(...)` maps transport failures to `OpenAIAPIUsageError.networkError(...)`.
  - `MoonshotUsageFetcher.fetchUsage(...)` maps invalid HTTP responses to `MoonshotUsageError.networkError(...)`.
- Preserve `CancellationError`. Do not convert cancellation into user-facing provider errors:
  - Cancellation checks exist in `Sources/TokenBar/UsageStore+TokenAccounts.swift`.
  - Cancellation propagation exists in vendored scanning paths such as `Sources/TokenBarCore/Vendored/CostUsage/CostUsageScanner.swift`.
- CLI errors should flow through `TokenBarCLI.makeErrorPayload(...)`, `TokenBarCLI.mapError(...)`, and `TokenBarCLI.printError(...)` in `Sources/TokenBarCLI/CLIErrorReporting.swift` rather than ad hoc stderr/JSON formatting.
- Do not rely on provider CLI status-line text for usage parsing. Claude CLI status line behavior is custom and user-configurable; use parser/fetcher seams in `Sources/TokenBarCore/Providers/Claude`.

## Logging

**Framework:** `swift-log` plus TokenBar wrappers.

**Patterns:**
- Use `CodexBarLog.logger(LogCategories.<category>)` instead of direct `print` in production code:
  - `Sources/TokenBarCore/Logging/CodexBarLog.swift`
  - `Sources/TokenBarCore/Logging/LogCategories.swift`
  - `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
- Logging can target stderr, OSLog, file logging, or discard through `CodexBarLog.Configuration` in `Sources/TokenBarCore/Logging/CodexBarLog.swift`.
- All messages and metadata pass through `LogRedactor.redact(...)` in `Sources/TokenBarCore/Logging/LogRedactor.swift`.
- Never log raw credentials, cookies, bearer values, API keys, tokens, or private account artifacts. Redaction patterns cover emails, cookie headers, authorization headers, bearer tokens, and provider token shapes in `Sources/TokenBarCore/Logging/LogRedactor.swift`.
- For tests that inspect logs or diagnostics, assert redacted/safe output only:
  - `Tests/TokenBarTests/MiniMaxLogRedactorTests.swift`
  - `Tests/TokenBarTests/ProviderDiagnosticExportTests.swift`
  - `Tests/TokenBarTests/CLIArgumentParsingTests.swift`

## Comments

**When to Comment:**
- Use comments to document architectural constraints and safety rules, not obvious assignments.
- Keep protocol and descriptor comments when they encode ownership rules:
  - `ProviderImplementation` rules in `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`
  - Provider metadata comments in `Sources/TokenBarCore/Providers/Providers.swift`
- Use `// MARK: -` to separate major sections. SwiftFormat enforces marks for types and extensions through `.swiftformat`.
- Use scoped formatter comments only when preserving intentional order or generated structure:
  - `// swiftformat:disable sortDeclarations` in `Sources/TokenBarCore/Providers/Providers.swift`

**JSDoc/TSDoc:**
- Not applicable. This is a Swift codebase.
- Use Swift `///` doc comments for public APIs, protocol rules, and data fields that guide consumers:
  - `ProviderMetadata.changelogURL` in `Sources/TokenBarCore/Providers/Providers.swift`
  - `ProviderImplementation.settingsToggles(...)` in `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`

## Function Design

**Size:** Keep functions focused and below the SwiftLint body limit. Split long behavior into helpers, extension files, or typed strategy structs.

**Parameters:** Use explicit dependency injection for code that touches network, storage, processes, or time:
- Inject `ProviderHTTPTransport` into provider fetchers:
  - `OpenAIAPIUsageFetcher.fetchUsage(..., session:)` in `Sources/TokenBarCore/Providers/OpenAI/OpenAIAPIUsageFetcher.swift`
  - `MoonshotUsageFetcher.fetchUsage(..., session:)` in `Sources/TokenBarCore/Providers/Moonshot/MoonshotUsageFetcher.swift`
- Inject `UserDefaults`, config stores, keychain stores, token stores, browser detection, and startup behavior:
  - `SettingsStore.init(...)` in `Sources/TokenBar/SettingsStore.swift`
  - `UsageStore.init(...)` in `Sources/TokenBar/UsageStore.swift`
- Use `@Sendable` closures for async/concurrent callbacks:
  - `ProviderHTTPTransportHandler` in `Sources/TokenBarCore/ProviderHTTPClient.swift`
  - test actor stubs in `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`

**Return Values:** Prefer typed result models and snapshots over dictionaries or raw strings:
- `UsageSnapshot`, `CreditsSnapshot`, `ProviderFetchResult`, `ProviderFetchOutcome`, and provider-specific `*UsageSnapshot` types in `Sources/TokenBarCore`.
- App-side providers return descriptor models, not custom SwiftUI views:
  - `ProviderSettingsToggleDescriptor`
  - `ProviderSettingsFieldDescriptor`
  - `ProviderSettingsPickerDescriptor`
  - `ProviderMenuEntry`
  - All are consumed through `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`.

## Module Design

**Exports:** Use `public` in `Sources/TokenBarCore` and `Sources/TokenBarCLI` only for APIs consumed across SwiftPM targets. Keep app-only details internal in `Sources/TokenBar`.

**Barrel Files:** Use registry and catalog files instead of ad hoc global lookup:
- `Sources/TokenBarCore/Providers/ProviderDescriptor.swift` owns `ProviderDescriptorRegistry`.
- `Sources/TokenBarCore/Providers/Providers.swift` owns `UsageProvider`, `IconStyle`, metadata defaults, and browser cookie default ordering.
- `Sources/TokenBar/ProviderRegistry.swift` and `Sources/TokenBar/Providers/Shared/ProviderImplementationRegistry.swift` bridge descriptors into app runtime behavior.

**Provider Pattern:**
- Add core provider behavior under `Sources/TokenBarCore/Providers/<Provider>/`.
- Add app-side settings/UI behavior under `Sources/TokenBar/Providers/<Provider>/`.
- Register core descriptors with `@ProviderDescriptorRegistration` / `@ProviderDescriptorDefinition` from `TokenBarMacroSupport`.
- Register app implementations with `@ProviderImplementationRegistration`.
- Keep identity, plan, account, and usage data siloed per provider. Do not render Claude identity/plan fields in Codex UI or Codex fields in Claude UI. The ownership rule is documented in `Sources/TokenBar/Providers/Shared/ProviderImplementation.swift`.

**Swift Concurrency:**
- SwiftPM enables `StrictConcurrency` for targets in `Package.swift`.
- Mark UI/state-owning types `@MainActor`:
  - `SettingsStore` in `Sources/TokenBar/SettingsStore.swift`
  - `UsageStore` in `Sources/TokenBar/UsageStore.swift`
  - SwiftUI views such as `PreferencesView` in `Sources/TokenBar/PreferencesView.swift`
- Use actors for mutable async test doubles and blockers:
  - `ProviderHTTPTransportStub` in `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`
  - `CoalescingManagedOpenAIDashboardLoader` in `Tests/TokenBarTests/CodexManagedOpenAIWebTestSupport.swift`
- Use `withTaskGroup` or `withThrowingTaskGroup` when multiple child tasks need explicit draining, cancellation, and required/optional failure semantics:
  - `UsageStore.refresh()` paths in `Sources/TokenBar/UsageStore.swift`
  - `UsageFetcher` timeout helper in `Sources/TokenBarCore/UsageFetcher.swift`
  - provider fetchers such as `Sources/TokenBarCore/Providers/Abacus/AbacusUsageFetcher.swift`
- Treat sibling `async let` as a review hotspot unless all children are equally required and failures are meant to propagate together. Prefer sequential awaits or a drained task group when one child is optional or best-effort.
- Detached tasks must have a clear boundary for background work, cancellation, and main-actor handoff:
  - Timer loops in `Sources/TokenBar/UsageStore.swift`
  - File/storage work in `Sources/TokenBar/UsageStore+ProviderStorage.swift`
  - Persistence in `Sources/TokenBar/SettingsStore+ConfigPersistence.swift`

**SwiftUI and AppKit:**
- Use modern Observation rather than `ObservableObject`:
  - `@Observable` models in `Sources/TokenBar/SettingsStore.swift`, `Sources/TokenBar/UsageStore.swift`, `Sources/TokenBar/PreferencesSelection.swift`, `Sources/TokenBar/DisplayLink.swift`.
  - Root ownership through `@State` in `Sources/TokenBar/TokenBarApp.swift`.
  - View access through `@Bindable` in `Sources/TokenBar/PreferencesView.swift`, `Sources/TokenBar/PreferencesProvidersPane.swift`, and `Sources/TokenBar/MenuContent.swift`.
- Avoid `@ObservedObject`, `@StateObject`, and `ObservableObject` for refactors and added UI state.
- Prefer descriptor/model seams over live AppKit objects for menu behavior:
  - `MenuDescriptor` in `Sources/TokenBar/MenuDescriptor.swift`
  - `ProvidersPane` testing helpers in `Sources/TokenBar/PreferencesProvidersPane+Testing.swift`
  - menu card models in `Sources/TokenBar/StatusItemController+MenuCardModel.swift`
- Use modern macOS APIs when available and preserve fallback paths for the package platform:
  - `DisplayLinkDriver` uses `NSScreen.displayLink` on macOS 15+ and `CVDisplayLink` fallback in `Sources/TokenBar/DisplayLink.swift`.

---

*Convention analysis: 2026-06-15*
