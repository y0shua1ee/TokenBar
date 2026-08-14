import Foundation
import Testing
@testable import CodexBarCore

struct KrillCostUsageFetcherTests {
    @Test
    func `clamps requested history window and scopes snapshot to credential`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/request-logs/stats":
                Self.response(for: request, body: #"""
                {"success":true,"data":{"total_requests":1,"total_tokens":100,"total_cost_usd":"0.25",
                  "trend":[{"bucket_start":"2027-01-15T08:00:00Z","request_count":1,
                            "total_tokens":100,"total_cost_usd":"0.25"}]}}
                """#)
            case "/api/request-logs/model-stats":
                Self.response(for: request, body: #"{"success":true,"data":{"items":[]}}"#)
            default:
                Self.response(for: request, status: 404, body: "{}")
            }
        }

        let snapshot = try await KrillCostUsageFetcher.loadTokenSnapshot(
            jwt: jwt,
            now: now,
            historyDays: 999,
            calendar: calendar,
            transport: transport)

        #expect(snapshot.historyDays == 365)
        #expect(snapshot.last30DaysTokens == 100)
        #expect(snapshot.last30DaysCostUSD == 0.25)
        #expect(snapshot.credentialScopeFingerprint == KrillJWT.credentialFingerprint(jwt))
        #expect(snapshot.credentialScopeFingerprint?.contains(jwt) == false)

        let statsRequests = await transport.requests().filter { $0.url?.path == "/api/request-logs/stats" }
        #expect(statsRequests.count == 2)
        let rollingBody = try Self.rangeBody(for: #require(statsRequests.first))
        let todayStart = calendar.startOfDay(for: now)
        let expectedStart = try #require(calendar.date(byAdding: .day, value: -364, to: todayStart))
        #expect(Self.date(rollingBody.startTime) == expectedStart)
        #expect(Self.date(rollingBody.endTime) == now)
    }

    @Test(arguments: [(0, 1), (1, 1), (30, 30), (365, 365), (500, 365)])
    func `history days clamps to supported range`(input: Int, expected: Int) {
        #expect(KrillCostUsageFetcher.clampedHistoryDays(input) == expected)
    }

    @Test
    func `decodes flexible model stats numbers`() throws {
        let stats = try Self.decode(KrillModelStatsResponse.self, #"""
        {"success":true,"data":{"items":[
          {"model":"test-model-alpha","request_count":"2","total_tokens":"81927506",
           "total_cost_usd":"103.115462"},
          {"model":"test-model-beta","request_count":1,"total_tokens":2000,"total_cost_usd":15.5}
        ]}}
        """#)
        let breakdowns = KrillCostUsageFetcher.modelBreakdowns(from: stats.data?.items ?? [])
        #expect(breakdowns.map(\.modelName) == ["test-model-alpha", "test-model-beta"])
        #expect(breakdowns[0].totalTokens == 81_927_506)
        #expect(breakdowns[0].requestCount == 2)
    }

    @Test
    func `treats unsuccessful model stats as unavailable`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/request-logs/stats":
                Self.response(
                    for: request,
                    body: #"{"success":true,"data":{"total_requests":1,"total_tokens":100}}"#)
            case "/api/request-logs/model-stats":
                Self.response(
                    for: request,
                    body: #"{"success":false,"data":{"items":[{"model":"test-model-alpha","total_tokens":100}]}}"#)
            default:
                Self.response(for: request, status: 404, body: "{}")
            }
        }

        let snapshot = try await KrillCostUsageFetcher.loadTokenSnapshot(
            jwt: jwt,
            now: now,
            historyDays: 30,
            transport: transport)

        #expect(snapshot.daily.allSatisfy { $0.modelBreakdowns == nil })
    }

    @Test
    func `optional model stats cancellation cancels token snapshot`() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/request-logs/stats":
                Self.response(
                    for: request,
                    body: #"{"success":true,"data":{"total_requests":1,"total_tokens":100}}"#)
            case "/api/request-logs/model-stats":
                throw URLError(.cancelled)
            default:
                Self.response(for: request, status: 404, body: "{}")
            }
        }

        await #expect(throws: CancellationError.self) {
            _ = try await KrillCostUsageFetcher.loadTokenSnapshot(
                jwt: jwt,
                now: now,
                historyDays: 30,
                transport: transport)
        }
    }

    @Test
    func `builds local day entries`() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2027,
            month: 1,
            day: 15,
            hour: 10)))
        let stats = try Self.decode(KrillStatsResponse.self, #"""
        {"success":true,"data":{"total_requests":2,"input_tokens":100,"output_tokens":20,
          "total_tokens":120,"total_cost_usd":"0.12"}}
        """#)
        let payload = try #require(stats.data)
        let entry = try #require(KrillCostUsageFetcher.entry(
            dayStart: calendar.startOfDay(for: now),
            stats: payload,
            calendar: calendar))
        #expect(entry.date == "2027-01-15")
        #expect(entry.requestCount == 2)
        #expect(entry.costUSD == 0.12)
    }

    private static func rangeBody(for request: URLRequest) throws -> (startTime: String, endTime: String) {
        let data = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        return try (
            startTime: #require(object["start_time"]),
            endTime: #require(object["end_time"]))
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, _ value: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(value.utf8))
    }

    private static func response(for request: URLRequest, body: String) -> (Data, URLResponse) {
        self.response(for: request, status: 200, body: body)
    }

    private static func response(for request: URLRequest, status: Int, body: String) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil)!
        return (Data(body.utf8), response)
    }
}
