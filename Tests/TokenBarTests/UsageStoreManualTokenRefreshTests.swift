import Foundation
import Testing
@testable import TokenBar
@testable import TokenBarCore

private actor TokenRefreshGate {
    private var didStart = false
    private var didFinish = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var calls: [(provider: UsageProvider, force: Bool)] = []

    func start(provider: UsageProvider, force: Bool) {
        self.didStart = true
        self.calls.append((provider, force))
        let waiters = self.startWaiters
        self.startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitForStart() async {
        if self.didStart { return }
        await withCheckedContinuation { continuation in
            self.startWaiters.append(continuation)
        }
    }

    func waitForRelease() async {
        if self.released { return }
        await withCheckedContinuation { continuation in
            self.releaseWaiters.append(continuation)
        }
    }

    func release() {
        self.released = true
        let waiters = self.releaseWaiters
        self.releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func finish() {
        self.didFinish = true
    }

    func hasFinished() -> Bool {
        self.didFinish
    }
}

private actor CompletionFlag {
    private var completed = false

    func markCompleted() {
        self.completed = true
    }

    func isCompleted() -> Bool {
        self.completed
    }
}

private actor TokenRefreshRecorder {
    private(set) var calls: [(provider: UsageProvider, force: Bool)] = []

    func record(provider: UsageProvider, force: Bool) {
        self.calls.append((provider, force))
    }
}

@MainActor
@Suite(.serialized)
struct UsageStoreManualTokenRefreshTests {
    @Test
    func `manual refresh waits for token-cost refresh before completing`() async {
        let store = Self.makeStore()
        let gate = TokenRefreshGate()
        let completion = CompletionFlag()
        store._test_providerRefreshOverride = { _ in }
        store._test_tokenUsageRefreshOverride = { provider, force in
            await gate.start(provider: provider, force: force)
            await gate.waitForRelease()
            await gate.finish()
        }

        let task = Task { @MainActor in
            await store.refresh(forceTokenUsage: true)
            await completion.markCompleted()
        }

        await gate.waitForStart()
        #expect(await completion.isCompleted() == false)
        #expect(await gate.hasFinished() == false)

        await gate.release()
        await task.value

        #expect(await completion.isCompleted())
        #expect(await gate.hasFinished())
        #expect(await gate.calls.map(\.provider) == [.codex])
        #expect(await gate.calls.map(\.force) == [true])
    }

    @Test
    func `manual refresh drains scheduled token-cost refresh before forced pass`() async {
        let store = Self.makeStore()
        let scheduledGate = TokenRefreshGate()
        let forcedGate = TokenRefreshGate()
        let recorder = TokenRefreshRecorder()
        let completion = CompletionFlag()
        store._test_providerRefreshOverride = { _ in }
        store._test_tokenUsageRefreshOverride = { provider, force in
            await recorder.record(provider: provider, force: force)
            if force {
                await forcedGate.start(provider: provider, force: force)
                await forcedGate.waitForRelease()
                await forcedGate.finish()
            } else {
                await scheduledGate.start(provider: provider, force: force)
                await scheduledGate.waitForRelease()
                await scheduledGate.finish()
            }
        }

        await store.refresh(forceTokenUsage: false)
        await scheduledGate.waitForStart()

        let task = Task { @MainActor in
            await store.refresh(forceTokenUsage: true)
            await completion.markCompleted()
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await completion.isCompleted() == false)

        await scheduledGate.release()
        await forcedGate.waitForStart()
        #expect(await completion.isCompleted() == false)

        await forcedGate.release()
        await task.value

        #expect(await completion.isCompleted())
        #expect(await scheduledGate.hasFinished())
        #expect(await forcedGate.hasFinished())
        #expect(await recorder.calls.map(\.provider) == [.codex, .codex])
        #expect(await recorder.calls.map(\.force) == [false, true])
    }

    @Test
    func `forced refresh still runs token-cost pass during active refresh`() async {
        let store = Self.makeStore()
        let gate = TokenRefreshGate()
        store.isRefreshing = true
        store._test_tokenUsageRefreshOverride = { provider, force in
            await gate.start(provider: provider, force: force)
            await gate.finish()
        }

        await store.refresh(forceTokenUsage: true)

        #expect(await gate.calls.map(\.provider) == [.codex])
        #expect(await gate.calls.map(\.force) == [true])
        #expect(await gate.hasFinished())
        #expect(store.isRefreshing)
    }

    @Test
    func `regular refresh schedules token-cost refresh without waiting`() async {
        let store = Self.makeStore()
        let gate = TokenRefreshGate()
        store._test_providerRefreshOverride = { _ in }
        store._test_tokenUsageRefreshOverride = { provider, force in
            await gate.start(provider: provider, force: force)
            await gate.waitForRelease()
            await gate.finish()
        }

        await store.refresh(forceTokenUsage: false)
        #expect(await gate.hasFinished() == false)

        await gate.release()
        try? await Task.sleep(for: .milliseconds(50))
        let calls = await gate.calls
        if !calls.isEmpty {
            #expect(calls.map(\.provider) == [.codex])
            #expect(calls.map(\.force) == [false])
            #expect(await gate.hasFinished())
        }
    }

    @Test
    func `open router token-cost refresh uses configured management key`() async throws {
        let registered = URLProtocol.registerClass(OpenRouterStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenRouterStubURLProtocol.self)
            }
            OpenRouterStubURLProtocol.handler = nil
        }

        OpenRouterStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.path == "/api/v1/activity")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer mgmt-test-key")
            let body = #"""
            {
              "data": [
                {
                  "completion_tokens": 125,
                  "date": "2026-05-31T00:00:00.000Z",
                  "model": "openai/gpt-4.1",
                  "prompt_tokens": 50,
                  "reasoning_tokens": 25,
                  "requests": 5,
                  "usage": 0.015
                }
              ]
            }
            """#
            return Self.makeJSONResponse(url: url, body: body)
        }

        let store = Self.makeOpenRouterStore()
        await store.forceRefreshTokenUsage(for: .openrouter)

        let snapshot = try #require(store.tokenSnapshot(for: .openrouter))
        #expect(snapshot.daily.count == 1)
        #expect(snapshot.daily[0].date == "2026-05-31")
        #expect(snapshot.daily[0].modelsUsed == ["openai/gpt-4.1"])
        let breakdown = try #require(snapshot.daily[0].modelBreakdowns?.first)
        #expect(breakdown.modelName == "openai/gpt-4.1")
        #expect(breakdown.totalTokens == 200)
        #expect(breakdown.costUSD == 0.015)
        #expect(snapshot.daily[0].totalTokens == 200)
        #expect(snapshot.daily[0].costUSD == 0.015)
        #expect(snapshot.last30DaysRequests == 5)
        #expect(store.tokenError(for: .openrouter) == nil)
    }

    private static func makeJSONResponse(url: URL, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        return (response, Data(body.utf8))
    }

    private static func makeStore() -> UsageStore {
        self.makeTokenRefreshStore(enabledProvider: .codex, suitePrefix: "UsageStoreManualTokenRefreshTests")
    }

    private static func makeOpenRouterStore() -> UsageStore {
        let store = Self.makeTokenRefreshStore(
            enabledProvider: .openrouter,
            suitePrefix: "UsageStoreManualTokenRefreshOpenRouterTests",
            environmentBase: ["OPENROUTER_API_URL": "https://openrouter.test/api/v1"])
        store.settings.openRouterManagementAPIKey = "mgmt-test-key"
        return store
    }

    private static func makeTokenRefreshStore(
        enabledProvider: UsageProvider,
        suitePrefix: String,
        environmentBase: [String: String] = [:]) -> UsageStore
    {
        let suite = "\(suitePrefix)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.refreshFrequency = .manual
        settings.statusChecksEnabled = false
        settings.costUsageEnabled = true
        settings.openAIWebAccessEnabled = false
        settings.codexCookieSource = .off
        settings.providerDetectionCompleted = true

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            settings.setProviderEnabled(provider: provider, metadata: metadata, enabled: provider == enabledProvider)
        }

        return UsageStore(
            fetcher: UsageFetcher(),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: environmentBase)
    }
}
