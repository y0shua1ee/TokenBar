import Foundation
import Testing
@testable import TokenBarCore

@Suite(.serialized)
struct OpenRouterUsageStatsTests {
    @Test
    func `to usage snapshot uses key quota for primary window`() {
        let snapshot = OpenRouterUsageSnapshot(
            totalCredits: 50,
            totalUsage: 45.3895596325,
            balance: 4.6104403675,
            usedPercent: 90.779119265,
            keyLimit: 20,
            keyUsage: 5,
            rateLimit: nil,
            updatedAt: Date(timeIntervalSince1970: 1_739_841_600))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary?.usedPercent == 25)
        #expect(usage.primary?.resetsAt == nil)
        #expect(usage.primary?.resetDescription == nil)
        #expect(usage.openRouterUsage?.keyQuotaStatus == .available)
    }

    @Test
    func `to usage snapshot without valid key limit omits primary window`() {
        let snapshot = OpenRouterUsageSnapshot(
            totalCredits: 50,
            totalUsage: 45.3895596325,
            balance: 4.6104403675,
            usedPercent: 90.779119265,
            keyLimit: nil,
            keyUsage: nil,
            rateLimit: nil,
            updatedAt: Date(timeIntervalSince1970: 1_739_841_600))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary == nil)
        #expect(usage.openRouterUsage?.keyQuotaStatus == .unavailable)
    }

    @Test
    func `to usage snapshot when no limit configured omits primary and marks no limit`() {
        let snapshot = OpenRouterUsageSnapshot(
            totalCredits: 50,
            totalUsage: 45.3895596325,
            balance: 4.6104403675,
            usedPercent: 90.779119265,
            keyDataFetched: true,
            keyLimit: nil,
            keyUsage: nil,
            rateLimit: nil,
            updatedAt: Date(timeIntervalSince1970: 1_739_841_600))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary == nil)
        #expect(usage.openRouterUsage?.keyQuotaStatus == .noLimitConfigured)
    }

    @Test
    func `sanitizers redact sensitive token shapes`() {
        let body = """
        {"error":"bad token sk-or-v1-abc123","token":"secret-token","authorization":"Bearer sk-or-v1-xyz789"}
        """

        let summary = OpenRouterUsageFetcher._sanitizedResponseBodySummaryForTesting(body)
        let debugBody = OpenRouterUsageFetcher._redactedDebugResponseBodyForTesting(body)

        #expect(summary.contains("sk-or-v1-[REDACTED]"))
        #expect(summary.contains("\"token\":\"[REDACTED]\""))
        #expect(!summary.contains("secret-token"))
        #expect(!summary.contains("sk-or-v1-abc123"))

        #expect(debugBody?.contains("sk-or-v1-[REDACTED]") == true)
        #expect(debugBody?.contains("\"token\":\"[REDACTED]\"") == true)
        #expect(debugBody?.contains("secret-token") == false)
        #expect(debugBody?.contains("sk-or-v1-xyz789") == false)
    }

    @Test
    func `non200 fetch throws generic HTTP error without body details`() async throws {
        let registered = URLProtocol.registerClass(OpenRouterStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenRouterStubURLProtocol.self)
            }
            OpenRouterStubURLProtocol.handler = nil
        }

        OpenRouterStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let body = #"{"error":"invalid sk-or-v1-super-secret","token":"dont-leak-me"}"#
            return Self.makeResponse(url: url, body: body, statusCode: 401)
        }

        do {
            _ = try await OpenRouterUsageFetcher.fetchUsage(
                apiKey: "sk-or-v1-test",
                environment: ["OPENROUTER_API_URL": "https://openrouter.test/api/v1"])
            Issue.record("Expected OpenRouterUsageError.apiError")
        } catch let error as OpenRouterUsageError {
            guard case let .apiError(message) = error else {
                Issue.record("Expected apiError, got: \(error)")
                return
            }
            #expect(message == "HTTP 401")
            #expect(!message.contains("dont-leak-me"))
            #expect(!message.contains("sk-or-v1-super-secret"))
        }
    }

    @Test
    func `fetch usage sets credits timeout and client headers`() async throws {
        let registered = URLProtocol.registerClass(OpenRouterStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenRouterStubURLProtocol.self)
            }
            OpenRouterStubURLProtocol.handler = nil
        }

        OpenRouterStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            switch url.path {
            case "/api/v1/credits":
                #expect(request.timeoutInterval == 15)
                #expect(request.value(forHTTPHeaderField: "HTTP-Referer") == "https://codexbar.example")
                #expect(request.value(forHTTPHeaderField: "X-Title") == "TokenBar QA")
                let body = #"{"data":{"total_credits":100,"total_usage":40}}"#
                return Self.makeResponse(url: url, body: body, statusCode: 200)
            case "/api/v1/key":
                let body = #"{"data":{"limit":20,"usage":0.5,"rate_limit":{"requests":120,"interval":"10s"}}}"#
                return Self.makeResponse(url: url, body: body, statusCode: 200)
            default:
                return Self.makeResponse(url: url, body: "{}", statusCode: 404)
            }
        }

        let usage = try await OpenRouterUsageFetcher.fetchUsage(
            apiKey: "sk-or-v1-test",
            environment: [
                "OPENROUTER_API_URL": "https://openrouter.test/api/v1",
                "OPENROUTER_HTTP_REFERER": " https://codexbar.example ",
                "OPENROUTER_X_TITLE": "TokenBar QA",
            ])

        #expect(usage.totalCredits == 100)
        #expect(usage.totalUsage == 40)
        #expect(usage.keyDataFetched)
        #expect(usage.keyLimit == 20)
        #expect(usage.keyUsage == 0.5)
        #expect(usage.keyRemaining == 19.5)
        #expect(usage.keyUsedPercent == 2.5)
        #expect(usage.keyQuotaStatus == .available)
    }

    @Test
    func `fetch usage when key endpoint fails marks quota unavailable`() async throws {
        let registered = URLProtocol.registerClass(OpenRouterStubURLProtocol.self)
        defer {
            if registered {
                URLProtocol.unregisterClass(OpenRouterStubURLProtocol.self)
            }
            OpenRouterStubURLProtocol.handler = nil
        }

        OpenRouterStubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            switch url.path {
            case "/api/v1/credits":
                let body = #"{"data":{"total_credits":100,"total_usage":40}}"#
                return Self.makeResponse(url: url, body: body, statusCode: 200)
            case "/api/v1/key":
                return Self.makeResponse(url: url, body: "{}", statusCode: 500)
            default:
                return Self.makeResponse(url: url, body: "{}", statusCode: 404)
            }
        }

        let usage = try await OpenRouterUsageFetcher.fetchUsage(
            apiKey: "sk-or-v1-test",
            environment: ["OPENROUTER_API_URL": "https://openrouter.test/api/v1"])

        #expect(!usage.keyDataFetched)
        #expect(usage.keyQuotaStatus == .unavailable)
    }

    @Test
    func `usage snapshot round trip persists open router usage metadata`() throws {
        let openRouter = OpenRouterUsageSnapshot(
            totalCredits: 50,
            totalUsage: 45.3895596325,
            balance: 4.6104403675,
            usedPercent: 90.779119265,
            keyDataFetched: true,
            keyLimit: nil,
            keyUsage: nil,
            rateLimit: nil,
            updatedAt: Date(timeIntervalSince1970: 1_739_841_600))
        let snapshot = openRouter.toUsageSnapshot()

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: data)

        #expect(decoded.openRouterUsage?.keyDataFetched == true)
        #expect(decoded.openRouterUsage?.keyQuotaStatus == .noLimitConfigured)
    }

    @Test
    func `activity report aggregates cost tokens requests and models by day`() {
        let report = OpenRouterActivityUsageFetcher.report(from: [
            OpenRouterActivityItem(
                byokUsageInference: 0.002,
                completionTokens: 125,
                date: "2025-08-24T00:00:00.000Z",
                endpointID: "endpoint-a",
                model: "openai/gpt-4.1",
                modelPermaslug: "openai/gpt-4.1-2025-04-14",
                promptTokens: 50,
                providerName: "OpenAI",
                reasoningTokens: 25,
                requests: 5,
                usage: 0.015),
            OpenRouterActivityItem(
                byokUsageInference: nil,
                completionTokens: 10,
                date: "2025-08-24 00:00:00",
                endpointID: "endpoint-b",
                model: "anthropic/claude-sonnet-4",
                modelPermaslug: nil,
                promptTokens: 20,
                providerName: "Anthropic",
                reasoningTokens: nil,
                requests: 2,
                usage: 0.004),
        ], now: Date(timeIntervalSince1970: 1_756_080_000))

        #expect(report.daily.count == 1)
        let day = report.daily[0]
        #expect(day.date == "2025-08-24")
        #expect(day.inputTokens == 70)
        #expect(day.outputTokens == 160)
        #expect(day.totalTokens == 230)
        #expect(day.costUSD == 0.021)
        #expect(day.modelsUsed == ["anthropic/claude-sonnet-4", "openai/gpt-4.1"])
        #expect(day.modelBreakdowns?.first?.modelName == "openai/gpt-4.1")
        #expect(report.requestsByDate["2025-08-24"] == 7)

        let snapshot = report.toTokenSnapshot(now: Date(timeIntervalSince1970: 1_756_080_000))
        #expect(snapshot.sessionRequests == 7)
        #expect(snapshot.last30DaysRequests == 7)
        #expect(snapshot.last30DaysTokens == 230)
        #expect(snapshot.last30DaysCostUSD == 0.021)
    }

    @Test
    func `activity fetcher calls activity endpoint with management key`() async throws {
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
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            let body = #"{"data":[{"byok_usage_inference":0.012,"completion_tokens":125,"date":"2025-08-24T00:00:00.000Z","endpoint_id":"550e8400-e29b-41d4-a716-446655440000","model":"openai/gpt-4.1","model_permaslug":"openai/gpt-4.1-2025-04-14","prompt_tokens":50,"provider_name":"OpenAI","reasoning_tokens":25,"requests":5,"usage":0.015}]}"#
            return Self.makeResponse(url: url, body: body, statusCode: 200)
        }

        let report = try await OpenRouterActivityUsageFetcher.loadDailyReport(
            managementKey: "mgmt-test-key",
            environment: ["OPENROUTER_API_URL": "https://openrouter.test/api/v1"],
            now: Date(timeIntervalSince1970: 1_756_080_000))

        #expect(report.daily.count == 1)
        #expect(report.daily[0].costUSD == 0.027)
        #expect(report.daily[0].totalTokens == 200)
        #expect(report.requestsByDate["2025-08-24"] == 5)
    }

    private static func makeResponse(
        url: URL,
        body: String,
        statusCode: Int = 200) -> (HTTPURLResponse, Data)
    {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        return (response, Data(body.utf8))
    }
}

final class OpenRouterStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "openrouter.test"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(self.request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        } catch {
            self.client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
