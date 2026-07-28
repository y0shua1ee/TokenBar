import Foundation
import Testing
@testable import TokenBarCore

struct DeepSeekProviderStrategyTests {
    private struct StubClaudeFetcher: ClaudeUsageFetching {
        func loadLatestUsage(model _: String) async throws -> ClaudeUsageSnapshot {
            throw ClaudeUsageError.parseFailed("stub")
        }

        func debugRawProbe(model _: String) async -> String {
            "stub"
        }

        func detectVersion() -> String? {
            nil
        }
    }

    private func makeContext(
        runtime: ProviderRuntime = .app,
        sourceMode: ProviderSourceMode = .auto,
        environment: [String: String] = [:]) -> ProviderFetchContext
    {
        ProviderFetchContext(
            runtime: runtime,
            sourceMode: sourceMode,
            includeCredits: false,
            webTimeout: 1,
            webDebugDumpHTML: false,
            verbose: false,
            env: environment,
            settings: nil,
            fetcher: UsageFetcher(environment: environment),
            claudeFetcher: StubClaudeFetcher(),
            browserDetection: BrowserDetection(cacheTTL: 0))
    }

    @Test
    func `source modes expose API first with dashboard fallback`() async {
        let descriptor = DeepSeekProviderDescriptor.descriptor
        let auto = await descriptor.fetchPlan.pipeline.resolveStrategies(self.makeContext())
        let api = await descriptor.fetchPlan.pipeline.resolveStrategies(self.makeContext(sourceMode: .api))
        let web = await descriptor.fetchPlan.pipeline.resolveStrategies(self.makeContext(sourceMode: .web))

        #expect(descriptor.fetchPlan.sourceModes == [.auto, .api, .web])
        #expect(auto.map(\.id) == ["deepseek.api", "deepseek.dashboard"])
        #expect(api.map(\.id) == ["deepseek.api"])
        #expect(web.map(\.id) == ["deepseek.dashboard"])
    }

    @Test
    func `dashboard strategy returns web usage without API credentials`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dashboard = DeepSeekDashboardUsageSnapshot(
            currencyCode: "CNY",
            monthlyCost: 4.25,
            requestCount: 12,
            totalTokens: 34000,
            models: ["deepseek-chat"],
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2027-01-15",
                    inputTokens: 20000,
                    outputTokens: 14000,
                    totalTokens: 34000,
                    requestCount: 12,
                    costUSD: 4.25,
                    modelsUsed: ["deepseek-chat"],
                    modelBreakdowns: nil),
            ],
            updatedAt: now)
        let strategy = DeepSeekDashboardFetchStrategy(dependencies: .init(
            loadToken: { "dashboard-token" },
            now: { now },
            fetchDashboard: { token, requestedAt in
                #expect(token == "dashboard-token")
                #expect(requestedAt == now)
                return dashboard
            }))

        let result = try await strategy.fetch(self.makeContext())

        #expect(result.strategyID == "deepseek.dashboard")
        if case .webDashboard = result.strategyKind {
            // Expected.
        } else {
            Issue.record("Expected DeepSeek dashboard fetch kind")
        }
        #expect(result.sourceLabel == "web")
        #expect(result.usage.primary == nil)
        #expect(result.usage.deepseekUsage?.currentMonthTokens == 34000)
        #expect(result.usage.deepseekUsage?.currentMonthRequestCount == 12)
    }

    @Test
    func `dashboard strategy reports missing login without reading network`() async {
        let strategy = DeepSeekDashboardFetchStrategy(dependencies: .init(
            loadToken: { nil },
            now: Date.init,
            fetchDashboard: { _, _ in
                Issue.record("Dashboard fetch must not run without a stored token")
                throw DeepSeekDashboardUsageError.networkError("unexpected")
            }))

        await #expect(throws: DeepSeekDashboardUsageError.self) {
            try await strategy.fetch(self.makeContext(sourceMode: .web))
        }
    }

    @Test
    func `API failures stay authoritative instead of crossing dashboard accounts`() {
        let strategy = DeepSeekAPIFetchStrategy()

        #expect(!strategy.shouldFallback(
            on: DeepSeekUsageError.apiError("expired"),
            context: self.makeContext()))
        #expect(!strategy.shouldFallback(
            on: DeepSeekUsageError.apiError("expired"),
            context: self.makeContext(sourceMode: .api)))
        #expect(!strategy.shouldFallback(
            on: CancellationError(),
            context: self.makeContext()))
        #expect(!strategy.shouldFallback(
            on: URLError(.cancelled),
            context: self.makeContext()))
    }

    @Test
    func `auto pipeline skips missing API credentials and returns dashboard usage`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dashboard = DeepSeekDashboardUsageSnapshot(
            currencyCode: "CNY",
            monthlyCost: 2.5,
            requestCount: 4,
            totalTokens: 1200,
            models: ["deepseek-chat"],
            daily: [],
            updatedAt: now)
        let dashboardStrategy = DeepSeekDashboardFetchStrategy(dependencies: .init(
            loadToken: { "dashboard-token" },
            now: { now },
            fetchDashboard: { _, _ in dashboard }))
        let pipeline = ProviderFetchPipeline(resolveStrategies: { _ in
            [DeepSeekAPIFetchStrategy(), dashboardStrategy]
        })

        let outcome = await pipeline.fetch(context: self.makeContext(), provider: .deepseek)
        let result = try outcome.result.get()

        #expect(result.sourceLabel == "web")
        #expect(result.usage.primary == nil)
        #expect(result.usage.deepseekUsage?.currentMonthTokens == 1200)
        #expect(outcome.attempts.map(\.strategyID) == ["deepseek.api", "deepseek.dashboard"])
        #expect(outcome.attempts.map(\.wasAvailable) == [false, true])
    }

    #if os(macOS)
    @Test
    func `dashboard availability supports macOS CLI and preserves configured API errors`() async {
        let missingDashboard = DeepSeekDashboardFetchStrategy(dependencies: .init(
            loadToken: { nil },
            now: Date.init,
            fetchDashboard: { _, _ in
                throw DeepSeekDashboardUsageError.networkError("unexpected")
            }))
        let storedDashboard = DeepSeekDashboardFetchStrategy(dependencies: .init(
            loadToken: { "dashboard-token" },
            now: Date.init,
            fetchDashboard: { _, _ in
                throw DeepSeekDashboardUsageError.networkError("unexpected")
            }))

        #expect(await missingDashboard.isAvailable(self.makeContext()))
        #expect(await missingDashboard.isAvailable(
            self.makeContext(environment: ["DEEPSEEK_API_KEY": "invalid-api-key"])) == false)
        #expect(await storedDashboard.isAvailable(
            self.makeContext(environment: ["DEEPSEEK_API_KEY": "invalid-api-key"])))
        #expect(await missingDashboard.isAvailable(self.makeContext(sourceMode: .web)))
        #expect(await storedDashboard.isAvailable(self.makeContext(runtime: .cli)))
        #expect(await missingDashboard.isAvailable(self.makeContext(runtime: .cli, sourceMode: .web)))
    }
    #endif
}
