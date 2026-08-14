import Foundation
import Testing
@testable import CodexBarCore

struct OpenRouterActivityUsageFetcherTests {
    @Test
    func `aggregates account activity without double counting reasoning tokens`() throws {
        let now = try Self.date("2025-08-26T12:00:00Z")
        let report = OpenRouterActivityUsageFetcher.report(from: [
            Self.item(
                date: "2025-08-24",
                model: "test-model-alpha",
                promptTokens: 50,
                completionTokens: 125,
                reasoningTokens: 25,
                requests: 5,
                usage: 0.015,
                byokUsageInference: 0.002),
            Self.item(
                date: "2025-08-24T00:00:00Z",
                model: "test-model-beta",
                promptTokens: 20,
                completionTokens: 10,
                reasoningTokens: nil,
                requests: 2,
                usage: 0.004),
        ], now: now)

        let day = try #require(report.daily.first)
        #expect(report.daily.count == 1)
        #expect(day.date == "2025-08-24")
        #expect(day.inputTokens == 70)
        #expect(day.outputTokens == 135)
        #expect(day.reasoningTokens == 25)
        #expect(day.totalTokens == 205)
        #expect(day.requestCount == 7)
        #expect(abs((day.costUSD ?? 0) - 0.021) < 0.000_000_1)
        #expect(day.modelsUsed == ["test-model-alpha", "test-model-beta"])
        #expect(day.modelBreakdowns?.first?.reasoningTokens == 25)
        #expect(report.reasoningTokensByDate["2025-08-24"] == 25)
        #expect(report.reasoningTokensByModelByDate["2025-08-24"]?["test-model-alpha"] == 25)

        let managementKey = "management-test-key"
        let snapshot = report.toTokenSnapshot(managementKey: managementKey, now: now)
        #expect(snapshot.sessionTokens == 205)
        #expect(snapshot.sessionRequests == 7)
        #expect(snapshot.last30DaysTokens == 205)
        #expect(snapshot.last30DaysRequests == 7)
        #expect(snapshot.historyDays == 30)
        #expect(snapshot.historyLabel == "Last 30 completed UTC days")
        #expect(snapshot.credentialScopeFingerprint?.count == 64)
        #expect(snapshot.credentialScopeFingerprint?.contains(managementKey) == false)

        let usage = report.toUsageSnapshot()
        #expect(usage.detailRow(label: "Latest completed UTC day")?.value == "2025-08-24")
        #expect(usage.detailRow(label: "Reasoning tokens")?.value == "25")
    }

    @Test
    func `keeps only requested completed UTC days`() throws {
        let now = try Self.date("2025-09-01T12:00:00Z")
        let report = OpenRouterActivityUsageFetcher.report(
            from: [
                Self.item(date: "2025-08-01", model: "test-model-oldest-minus-one"),
                Self.item(date: "2025-08-02", model: "test-model-oldest"),
                Self.item(date: "2025-08-31", model: "test-model-latest"),
                Self.item(date: "2025-09-01", model: "test-model-current"),
                Self.item(date: "2025-09-02", model: "test-model-future"),
            ],
            now: now,
            historyDays: 999)

        #expect(report.historyDays == 30)
        #expect(report.daily.map(\.date) == ["2025-08-02", "2025-08-31"])

        let oneDay = OpenRouterActivityUsageFetcher.report(
            from: [
                Self.item(date: "2025-08-30", model: "test-model-too-old"),
                Self.item(date: "2025-08-31", model: "test-model-yesterday"),
            ],
            now: now,
            historyDays: 0)
        #expect(oneDay.historyDays == 1)
        #expect(oneDay.daily.map(\.date) == ["2025-08-31"])
    }

    @Test
    func `activity request always uses fixed official endpoint`() async throws {
        let now = try Self.date("2025-08-26T12:00:00Z")
        let transport = ProviderHTTPTransportStub { request in
            #expect(request.url?.absoluteString == "https://openrouter.ai/api/v1/activity")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer management-test-key")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            return Self.response(for: request, body: #"{"data":[]}"#)
        }

        let report = try await OpenRouterActivityUsageFetcher.loadDailyReport(
            environment: [
                OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-test-key",
                OpenRouterSettingsReader.apiURLEnvironmentKey: "https://attacker.invalid/api/v1",
            ],
            now: now,
            transport: transport)

        #expect(await transport.requests().count == 1)
        #expect(report.daily.isEmpty)
        let noDataMessage = OpenRouterProviderDescriptor.descriptor.tokenCost.noDataMessage()
        #expect(noDataMessage == "No OpenRouter account activity was reported for this period.")
        #expect(!noDataMessage.localizedCaseInsensitiveContains("management key"))
    }

    @Test
    func `missing management key remains an explicit fetch error`() async {
        await #expect(throws: OpenRouterActivityUsageError.missingManagementKey) {
            _ = try await OpenRouterActivityUsageFetcher.loadDailyReport(environment: [:])
        }
    }

    @Test(arguments: [
        (401, OpenRouterActivityUsageError.authenticationRejected),
        (403, .permissionDenied),
        (429, .rateLimited),
        (500, .apiError(500)),
    ])
    func `activity maps HTTP failures`(
        statusCode: Int,
        expectedError: OpenRouterActivityUsageError) async
    {
        let transport = ProviderHTTPTransportStub { request in
            Self.response(for: request, body: #"{"error":"test"}"#, statusCode: statusCode)
        }

        await #expect(throws: expectedError) {
            _ = try await OpenRouterActivityUsageFetcher.loadDailyReport(
                managementKey: "management-test-key",
                transport: transport)
        }
    }

    @Test
    func `activity rejects invalid JSON`() async {
        let transport = ProviderHTTPTransportStub { request in
            Self.response(for: request, body: "not-json")
        }

        await #expect(throws: OpenRouterActivityUsageError.invalidResponse) {
            _ = try await OpenRouterActivityUsageFetcher.loadDailyReport(
                managementKey: "management-test-key",
                transport: transport)
        }
    }

    @Test
    func `transport cancellation propagates as cancellation`() async throws {
        let transport = ProviderHTTPTransportStub { _ in throw URLError(.cancelled) }

        await #expect(throws: CancellationError.self) {
            _ = try await OpenRouterActivityUsageFetcher.loadDailyReport(
                managementKey: "management-test-key",
                transport: transport)
        }
    }

    @Test
    func `settings keep management and ordinary keys isolated`() {
        let environment = [
            OpenRouterSettingsReader.envKey: "ordinary-key",
            OpenRouterSettingsReader.managementKeyEnvironmentKey: "  'management-key'  ",
        ]
        #expect(OpenRouterSettingsReader.apiToken(environment: environment) == "ordinary-key")
        #expect(OpenRouterSettingsReader.managementKey(environment: environment) == "management-key")
        #expect(OpenRouterSettingsReader.managementKey(environment: [
            OpenRouterSettingsReader.envKey: "ordinary-key",
        ]) == nil)
    }

    @Test
    func `descriptor projects and diagnoses a management-only credential`() throws {
        let descriptor = OpenRouterProviderDescriptor.descriptor
        let credentials = try #require(descriptor.credentials)
        let projected = credentials.applyConfig(
            base: [:],
            config: ProviderConfig(
                id: .openrouter,
                apiKey: "ordinary-config-key",
                secretKey: "management-config-key",
                enterpriseHost: "openrouter-proxy.test/api/v1"))

        #expect(credentials.usesSecretKey)
        #expect(credentials.requiresAPIKeyForAPISource == false)
        #expect(projected[OpenRouterSettingsReader.envKey] == "ordinary-config-key")
        #expect(projected[OpenRouterSettingsReader.managementKeyEnvironmentKey] == "management-config-key")
        #expect(projected[OpenRouterSettingsReader.apiURLEnvironmentKey] == "openrouter-proxy.test/api/v1")

        let auth = credentials.diagnosticAuthSummary(
            account: nil,
            config: nil,
            environment: [OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-key"],
            settings: nil)
        #expect(auth.configured)
        #expect(auth.modes == ["api"])
    }

    @Test
    func `fetch plan never routes account activity into token accounts`() async {
        let managementOnly = Self.context(environment: [
            OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-key",
        ])
        let managementStrategies = await OpenRouterProviderDescriptor.resolveStrategies(context: managementOnly)
        #expect(managementStrategies.map(\.id) == ["openrouter.activity"])
        #expect(await managementStrategies[0].isAvailable(managementOnly))

        let both = Self.context(environment: [
            OpenRouterSettingsReader.envKey: "ordinary-key",
            OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-key",
        ])
        #expect(await OpenRouterProviderDescriptor.resolveStrategies(context: both).map(\.id) == ["openrouter.js"])

        let tokenAccount = Self.context(
            environment: [
                OpenRouterSettingsReader.envKey: "selected-ordinary-key",
                OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-key",
            ],
            selectedTokenAccountID: UUID())
        let tokenStrategies = await OpenRouterProviderDescriptor.resolveStrategies(context: tokenAccount)
        #expect(tokenStrategies.map(\.id) == ["openrouter.js"])
        #expect(!tokenStrategies.contains { $0.id == "openrouter.activity" })
    }

    @Test
    func `token account scrub removes provider management key`() throws {
        let support = try #require(OpenRouterProviderDescriptor.descriptor.credentials?.tokenAccountSupport)
        var environment = [
            OpenRouterSettingsReader.envKey: "provider-ordinary-key",
            OpenRouterSettingsReader.managementKeyEnvironmentKey: "provider-management-key",
        ]
        support.scrubEnvironment(&environment, token: "selected-ordinary-key")
        #expect(environment[OpenRouterSettingsReader.envKey] == nil)
        #expect(environment[OpenRouterSettingsReader.managementKeyEnvironmentKey] == nil)
        try environment.merge(#require(support.envOverride(token: "selected-ordinary-key"))) { _, selected in selected }
        #expect(environment[OpenRouterSettingsReader.envKey] == "selected-ordinary-key")
        #expect(environment[OpenRouterSettingsReader.managementKeyEnvironmentKey] == nil)
    }

    @Test
    func `activity strategy succeeds with account details only`() async throws {
        let now = try Self.date("2025-08-26T12:00:00Z")
        let report = OpenRouterActivityUsageFetcher.report(from: [
            Self.item(
                date: "2025-08-24",
                model: "test-model-alpha",
                reasoningTokens: 11),
        ], now: now)
        let strategy = OpenRouterActivityFetchStrategy { key, days in
            #expect(key == "management-key")
            #expect(days == 12)
            return report
        }
        let context = Self.context(
            environment: [OpenRouterSettingsReader.managementKeyEnvironmentKey: "management-key"],
            costUsageHistoryDays: 12)

        let result = try await strategy.fetch(context)

        #expect(result.sourceLabel == "management-api")
        #expect(result.strategyID == "openrouter.activity")
        #expect(result.usage.primary == nil)
        #expect(result.usage.detailRow(label: "Latest completed UTC day")?.value == "2025-08-24")
        #expect(result.usage.detailRow(label: "Reasoning tokens")?.value == "11")
    }

    @Test
    func `credential fingerprint is deterministic trimmed and one way`() {
        let first = OpenRouterActivityUsageFetcher.credentialFingerprint(" management-key ")
        let same = OpenRouterActivityUsageFetcher.credentialFingerprint("management-key")
        let different = OpenRouterActivityUsageFetcher.credentialFingerprint("other-management-key")

        #expect(first == same)
        #expect(first != different)
        #expect(first.count == 64)
        #expect(!first.contains("management-key"))
    }

    private static func context(
        environment: [String: String],
        selectedTokenAccountID: UUID? = nil,
        costUsageHistoryDays: Int = 30) -> ProviderFetchContext
    {
        let browserDetection = BrowserDetection(cacheTTL: 0)
        return ProviderFetchContext(
            runtime: .app,
            sourceMode: .api,
            includeCredits: false,
            webTimeout: 1,
            webDebugDumpHTML: false,
            verbose: false,
            env: environment,
            settings: nil,
            fetcher: UsageFetcher(environment: environment),
            claudeFetcher: ClaudeUsageFetcher(browserDetection: browserDetection),
            browserDetection: browserDetection,
            selectedTokenAccountID: selectedTokenAccountID,
            costUsageHistoryDays: costUsageHistoryDays)
    }

    private static func item(
        date: String,
        model: String,
        promptTokens: Int? = 1,
        completionTokens: Int? = 2,
        reasoningTokens: Int? = 1,
        requests: Int? = 1,
        usage: Double? = 0.01,
        byokUsageInference: Double? = nil) -> OpenRouterActivityItem
    {
        OpenRouterActivityItem(
            byokUsageInference: byokUsageInference,
            completionTokens: completionTokens,
            date: date,
            endpointID: nil,
            model: model,
            modelPermaslug: nil,
            promptTokens: promptTokens,
            providerName: "Test Provider",
            reasoningTokens: reasoningTokens,
            requests: requests,
            usage: usage)
    }

    private static func response(
        for request: URLRequest,
        body: String,
        statusCode: Int = 200) -> (Data, URLResponse)
    {
        guard let response = HTTPURLResponse(
            url: request.url ?? OpenRouterActivityUsageFetcher.activityURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil)
        else {
            preconditionFailure("Test HTTP response must be valid")
        }
        return (Data(body.utf8), response)
    }

    private static func date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }
}
