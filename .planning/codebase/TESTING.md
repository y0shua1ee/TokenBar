# Testing Patterns

**Analysis Date:** 2026-06-15

## Test Framework

**Runner:**
- SwiftPM `swift test`.
- Config: `Package.swift`.
- Main macOS test target: `TokenBarTests`, path `Tests`, resources copied from `Tests/TokenBarTests/Fixtures`.
- Linux/core test target: `TokenBarLinuxTests`, path `TestsLinux`.
- `Package.swift` enables:
  - `StrictConcurrency` for production and test targets.
  - `SwiftTesting` experimental feature for `TokenBarTests` and `TokenBarLinuxTests`.
- Current test inventory:
  - `403` Swift files under `Tests/TokenBarTests`.
  - `390` files import `Testing`.
  - `5` files import `XCTest`.

**Assertion Library:**
- Primary: Swift Testing (`import Testing`) with `@Test`, `@Suite`, `#expect`, `#require`, and `Issue.record`.
- Compatibility: XCTest remains for a small number of `XCTestCase` suites such as `Tests/TokenBarTests/CLIEntryTests.swift`, `Tests/TokenBarTests/AugmentStatusProbeTests.swift`, and `Tests/TokenBarTests/StatusMenuTokenAccountSwitcherTests.swift`.
- Add tests with Swift Testing unless extending an existing XCTest file.

**Run Commands:**
```bash
swift test                                      # Run the full SwiftPM test suite
swift test --filter OpenAIDashboardParserTests # Run a focused parser suite
swift test --filter ProviderHTTPClientTests    # Run a focused HTTP transport suite
swift test --filter TTYIntegrationTests        # Run TTY suite; live parts are env-gated
swift test --no-parallel --filter '<suite>'    # Run a problematic suite serially
python3 Scripts/ci_swift_test_by_suite.py      # Run SwiftPM suites in CI-style shards
make check                                     # Run parser hash check, SwiftFormat lint, SwiftLint strict
make format                                    # Apply SwiftFormat to Sources and Tests
make test-live                                 # Opt-in live account test command; requires LIVE_TEST=1
```

## Test File Organization

**Location:**
- Tests are under `Tests/TokenBarTests`.
- Fixtures are under `Tests/TokenBarTests/Fixtures`.
- Shared test stores and helpers live beside test suites:
  - `Tests/TokenBarTests/TestStores.swift`
  - `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`
  - `Tests/TokenBarTests/ZaiTokenStoreTestSupport.swift`
  - `Tests/TokenBarTests/KimiK2TokenStoreTestSupport.swift`
  - `Tests/TokenBarTests/CodexManagedOpenAIWebTestSupport.swift`

**Naming:**
- Use `FeatureNameTests.swift` for suites:
  - `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - `Tests/TokenBarTests/OpenAIAPIUsageFetcherTests.swift`
  - `Tests/TokenBarTests/ProviderHTTPClientTests.swift`
  - `Tests/TokenBarTests/KeychainNoUIQueryTests.swift`
- Use `*TestSupport.swift` for helpers that are not suites:
  - `Tests/TokenBarTests/CodexAccountScopedRefreshTestSupport.swift`
  - `Tests/TokenBarTests/HistoricalUsagePaceTestSupport.swift`
  - `Tests/TokenBarTests/CodexAccountPromotionTestSupport.swift`
- Use test names as readable behavior sentences in backticks.

**Structure:**
```text
Tests/
`-- TokenBarTests/
    |-- *Tests.swift               # Swift Testing or remaining XCTest suites
    |-- *TestSupport.swift         # Shared helpers for a feature area
    |-- TestStores.swift           # In-memory stores and config-store helpers
    |-- ProviderHTTPTransportStub.swift
    `-- Fixtures/
        |-- codex-historical-usage-real-legacy.jsonl
        |-- codex-plan-utilization-real-migration.json
        `-- models-dev-subset.json
```

## Test Structure

**Suite Organization:**
```swift
import Foundation
import Testing
@testable import TokenBarCore

struct OpenAIAPIUsageFetcherTests {
    @Test
    func `admin usage fetch pages long history within endpoint bucket limit`() async throws {
        let transport = ProviderHTTPTransportStub { request in
            let response = try HTTPURLResponse(
                url: #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil)!
            return (Data(#"{"object":"page","data":[]}"#.utf8), response)
        }

        _ = try await OpenAIAPIUsageFetcher.fetchUsage(
            apiKey: "test-api-key",
            session: transport)

        #expect(await transport.requests().isEmpty == false)
    }
}
```

**Patterns:**
- Use Swift Testing structs by default:
  - `struct OpenAIDashboardParserTests` in `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - `struct ProviderHTTPClientTests` in `Tests/TokenBarTests/ProviderHTTPClientTests.swift`
- Mark suites `@MainActor` when exercising `SettingsStore`, `UsageStore`, SwiftUI, or AppKit state:
  - `Tests/TokenBarTests/SettingsStoreCoverageTests.swift`
  - `Tests/TokenBarTests/UsageStoreCoverageTests.swift`
  - `Tests/TokenBarTests/MenuDescriptorOpenAIAPITests.swift`
- Mark suites `@Suite(.serialized)` when they mutate global state, register `URLProtocol`, touch shared sessions, use process/session singletons, or rely on wall-clock coordination:
  - `Tests/TokenBarTests/ProviderHTTPClientTests.swift`
  - `Tests/TokenBarTests/BrowserDetectionTests.swift`
  - `Tests/TokenBarTests/SettingsStoreTests.swift`
  - `Tests/TokenBarTests/StatusMenuTests.swift`
- Use `#require` for values that must exist before assertions continue.
- Use `Issue.record(...)` when a custom branch needs to fail with context.
- Use `await #expect(throws:)` or `#expect(throws:)` for expected failures instead of manual bool flags when the exact thrown type is known.

## Mocking

**Framework:** Native Swift test doubles, Swift actors, `URLProtocol`, protocol injection, and scoped override helpers.

**Patterns:**
```swift
actor ProviderHTTPTransportStub: ProviderHTTPTransport {
    private let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private var recordedRequests: [URLRequest] = []

    func requests() -> [URLRequest] {
        self.recordedRequests
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.recordedRequests.append(request)
        return try await self.handler(request)
    }
}
```

**What to Mock:**
- Network transport through `ProviderHTTPTransportStub`:
  - `Tests/TokenBarTests/ProviderHTTPTransportStub.swift`
  - `Tests/TokenBarTests/OpenAIAPIUsageFetcherTests.swift`
  - `Tests/TokenBarTests/DeepgramProviderTests.swift`
  - `Tests/TokenBarTests/AzureOpenAIUsageFetcherTests.swift`
- URL loading through per-suite `URLProtocol` stubs when code uses `URLSession`:
  - `StubURLProtocol` in `Tests/TokenBarTests/ProviderHTTPClientTests.swift`
  - `OpenRouterStubURLProtocol` in `Tests/TokenBarTests/OpenRouterUsageStatsTests.swift`
  - `CursorStatusProbeStubURLProtocol` in `Tests/TokenBarTests/CursorStatusProbeTests.swift`
  - `FactoryStubURLProtocol` in `Tests/TokenBarTests/FactoryStatusProbeFetchTests.swift`
- User defaults and config files with isolated suite names and temp stores:
  - `testConfigStore(suiteName:)` in `Tests/TokenBarTests/TestStores.swift`
  - `UserDefaults(suiteName:)` plus `removePersistentDomain(forName:)` in `Tests/TokenBarTests/SettingsStoreCoverageTests.swift`
- Keychain/token/cookie stores with no-op or in-memory stores:
  - `NoopZaiTokenStore` in `Tests/TokenBarTests/ZaiTokenStoreTestSupport.swift`
  - `NoopSyntheticTokenStore` in `Tests/TokenBarTests/ZaiTokenStoreTestSupport.swift`
  - `NoopKimiK2TokenStore` in `Tests/TokenBarTests/KimiK2TokenStoreTestSupport.swift`
  - `InMemoryCookieHeaderStore`, `InMemoryTokenAccountStore`, and related stores in `Tests/TokenBarTests/TestStores.swift`
- Process and CLI behavior with fake executables in temp directories:
  - `Tests/TokenBarTests/TTYIntegrationTests.swift`
  - `Tests/TokenBarTests/TTYCommandRunnerTests.swift`
  - `Tests/TokenBarTests/CodexBaselineCharacterizationTests.swift`
- Async coalescing and blocking behavior with actor blockers:
  - `CoalescingManagedOpenAIDashboardLoader` in `Tests/TokenBarTests/CodexManagedOpenAIWebTestSupport.swift`
  - `BlockingManagedOpenAIDashboardLoader` in `Tests/TokenBarTests/CodexManagedOpenAIWebRefreshTests.swift`
  - `BlockingCodexFetchStrategy` in `Tests/TokenBarTests/CodexAccountScopedRefreshTestSupport.swift`

**What NOT to Mock:**
- Do not mock parser outputs when the parser is the unit under test. Feed real representative strings, HTML, JSON, rows, or fixture data:
  - `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - `Tests/TokenBarTests/OllamaUsageParserTests.swift`
  - `Tests/TokenBarTests/MistralUsageParserTests.swift`
  - `Tests/TokenBarTests/CostUsageJsonlScannerTests.swift`
- Do not construct live `NSStatusBar` / `NSMenu` flows unless AppKit wiring itself is under test. Prefer model seams:
  - `Sources/TokenBar/MenuDescriptor.swift`
  - `Sources/TokenBar/PreferencesProvidersPane+Testing.swift`
  - `Sources/TokenBar/StatusItemController+MenuCardModel.swift`
- Do not hit real provider APIs, browser cookie databases, or macOS Keychain during ordinary tests.
- Do not use real unreleased model names in tests. Use released model names or clearly fictitious names.

## Fixtures and Factories

**Test Data:**
```swift
let snapshot = OpenAIDashboardSnapshot(
    signedInEmail: "user@example.test",
    codeReviewRemainingPercent: 90,
    creditEvents: [],
    dailyBreakdown: [],
    usageBreakdown: [],
    creditsPurchaseURL: nil,
    creditsRemaining: 10,
    accountPlan: "Pro",
    updatedAt: Date())
```

**Location:**
- JSONL/history fixtures:
  - `Tests/TokenBarTests/Fixtures/codex-historical-usage-real-legacy.jsonl`
  - `Tests/TokenBarTests/Fixtures/codex-plan-utilization-real-migration.json`
  - `Tests/TokenBarTests/Fixtures/models-dev-subset.json`
- Shared store factories:
  - `testConfigStore(suiteName:)` in `Tests/TokenBarTests/TestStores.swift`
  - `testPlanUtilizationHistoryStore(suiteName:)` in `Tests/TokenBarTests/TestStores.swift`
- Auth/account factories:
  - `writeCodexAuthFile(...)` and `fakeJWT(...)` in `Tests/TokenBarTests/CodexManagedOpenAIWebTestSupport.swift`
  - helpers in `Tests/TokenBarTests/CodexAccountPromotionTestSupport.swift`
- Temp directories must be unique and cleaned with `defer { try? FileManager.default.removeItem(at:) }`.

## Coverage

**Requirements:** No numeric coverage target is enforced in repo config.

**View Coverage:**
```bash
swift test --enable-code-coverage              # Generate SwiftPM coverage data when needed
swift test --show-codecov-path                 # Print the generated coverage bundle path
```

Coverage commands are not wired into `Makefile`; use them as ad hoc analysis only.

## Test Types

**Unit Tests:**
- Parser and formatter tests use inline strings, JSON, or fixtures:
  - `Tests/TokenBarTests/OpenAIDashboardParserTests.swift`
  - `Tests/TokenBarTests/TextParsingTests.swift`
  - `Tests/TokenBarTests/UsageFormatterTests.swift`
  - `Tests/TokenBarTests/CostUsageDecodingTests.swift`
- Provider settings readers and token resolvers use environment dictionaries and config snapshots:
  - `Tests/TokenBarTests/BedrockSettingsReaderTests.swift`
  - `Tests/TokenBarTests/DeepSeekSettingsReaderTests.swift`
  - `Tests/TokenBarTests/KiloSettingsReaderTests.swift`
  - `Tests/TokenBarTests/ProviderConfigEnvironmentTests.swift`
- Menu/card behavior should assert descriptor/model state:
  - `Tests/TokenBarTests/MenuCardModelTests.swift`
  - `Tests/TokenBarTests/MenuDescriptorOpenAIAPITests.swift`
  - `Tests/TokenBarTests/CodexAccountsSectionStateTests.swift`
  - `Tests/TokenBarTests/ProvidersPaneCoverageTests.swift`

**Integration Tests:**
- HTTP integration within tests uses injected transports or `URLProtocol`, not real network:
  - `Tests/TokenBarTests/ProviderHTTPClientTests.swift`
  - `Tests/TokenBarTests/OpenAIAPIUsageFetcherTests.swift`
  - `Tests/TokenBarTests/GoogleWorkspaceStatusNetworkTests.swift`
- Filesystem/config/account integration uses temp directories:
  - `Tests/TokenBarTests/CodexAccountScopedRefreshTests.swift`
  - `Tests/TokenBarTests/CodexAccountVisibleHistoryBackfillTests.swift`
  - `Tests/TokenBarTests/ManagedCodexAccountStoreTests.swift`
- AppKit/menu integration is serialized and should release status items through helpers:
  - `withStatusItemControllerForTesting(...)` in `Tests/TokenBarTests/TestStores.swift`
  - `Tests/TokenBarTests/StatusMenuTests.swift`
  - `Tests/TokenBarTests/StatusItemControllerSplitLifecycleTests.swift`

**E2E Tests:**
- No broad automated E2E suite is configured in SwiftPM.
- Live account checks are opt-in:
  - `Tests/TokenBarTests/LiveAccountTests.swift`
  - `make test-live`
  - Requires `LIVE_TEST=1`.
- TTY live probes are opt-in inside `Tests/TokenBarTests/TTYIntegrationTests.swift`:
  - Codex live path requires `LIVE_CODEX_TTY=1`.
  - Claude live path requires `LIVE_CLAUDE_TTY=1`.
- Bundle-level UI/runtime validation uses `./Scripts/compile_and_run.sh` only when a change needs the packaged app. The script builds, tests, packages, launches `TokenBar.app`, and verifies it stays running.
- Live provider QA lives in `.agents/skills/qa-test/SKILL.md`. Use packaged CLI checks before menu QA, and do not substitute live browser/keychain paths for parser or stub tests.

## Common Patterns

**Async Testing:**
```swift
@Test
func `same account dashboard refresh requests coalesce while one is in flight`() async throws {
    let blocker = CoalescingManagedOpenAIDashboardLoader()
    let firstTask = Task { await store.refreshOpenAIDashboardIfNeeded(force: true, expectedGuard: guardValue) }
    await blocker.waitUntilStarted()
    let secondTask = Task { await store.refreshOpenAIDashboardIfNeeded(force: true, expectedGuard: guardValue) }

    #expect(await blocker.startedCount() == 1)
    await firstTask.value
    await secondTask.value
}
```
- Use actor blockers for deterministic task coordination.
- Use `Task.sleep` sparingly and only with short deterministic waits.
- Store and await spawned tasks before test exit.
- Assert cancellation with `CancellationError` when cancellation is the behavior under test:
  - `Tests/TokenBarTests/CostUsageCancellationTests.swift`
  - `Tests/TokenBarTests/CostUsageScanExecutorTests.swift`
  - `Tests/TokenBarTests/ClaudeCLITimeoutRetryTests.swift`

**Error Testing:**
```swift
@Test
func `response helper rejects non HTTP responses`() async throws {
    let transport = ProviderHTTPTransportHandler { request in
        let response = URLResponse(
            url: request.url!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil)
        return (Data(), response)
    }

    await #expect(throws: URLError.self) {
        _ = try await transport.response(for: request)
    }
}
```
- Prefer exact typed error assertions when possible:
  - `#expect(throws: KiloUsageError.missingCredentials)` in `Tests/TokenBarTests/KiloBearerTokenResolverTests.swift`
  - `await #expect(throws: CancellationError.self)` in `Tests/TokenBarTests/CostUsageScanExecutorTests.swift`
- Use manual `do/catch` plus `Issue.record(...)` only when matching associated values or branching on multiple acceptable errors.

**No-Keychain-Prompt Validation:**
- Ordinary tests must not trigger macOS Keychain prompts.
- Use `KeychainNoUIQuery.apply(to:)` and preflight query helpers:
  - `Sources/TokenBarCore/KeychainNoUIQuery.swift`
  - `Sources/TokenBarCore/KeychainAccessPreflight.swift`
  - `Tests/TokenBarTests/KeychainNoUIQueryTests.swift`
- Use scoped overrides for prompt-sensitive paths:
  - `KeychainAccessGate.withTaskOverrideForTesting(false)`
  - `KeychainCacheStore.withServiceOverrideForTesting(...)`
  - `ClaudeOAuthCredentialsStore.withCredentialsURLOverrideForTesting(...)`
  - `ClaudeOAuthCredentialsStore.withSecurityCLIReadOverrideForTesting(...)`
  - `KeychainAccessPreflight.withCheckGenericPasswordOverrideForTesting(...)`
- `Tests/TokenBarTests/KeychainPromptSafetyAuditTests.swift` enforces:
  - `AGENTS.md` contains the no-prompt rule.
  - Live TTY tests are env-gated.
  - Tests do not call `SecItemCopyMatching` except approved no-UI coverage and the audit itself.
  - `allowKeychainPrompt: true` call sites are inside approved keychain test doubles.
- Live provider probes, browser-cookie imports, `tokenbar usage` against real accounts, and real SecItem reads require explicit user request.

**CI and Local Verification:**
- Full handoff for code changes requires:
  - `swift test`
  - `make check`
- For parser/provider changes, run a focused filter first, then the full suite when feasible:
  - `swift test --filter OpenAIDashboardParserTests`
  - `swift test --filter ProviderHTTPClientTests`
  - `swift test --filter OpenAIAPIUsageFetcherTests`
- Use `python3 Scripts/ci_swift_test_by_suite.py` to reproduce CI shard behavior. The script:
  - discovers suites with `swift test list`;
  - runs shards with `swift test --no-parallel --filter`;
  - retries timed-out shards suite-by-suite;
  - skips `TokenBarTests.CLIEntryTests` only for GitHub Actions macOS runners.
- If SwiftPM sandboxing blocks local validation on macOS, use the explicit SwiftPM sandbox workaround only for the affected command and report that boundary in the handoff.

---

*Testing analysis: 2026-06-15*
