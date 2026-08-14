import Foundation
import Testing
@testable import CodexBarCore

struct KrillAPIClientTests {
    @Test
    func `uses same origin routes bearer auth and typed POST body`() async throws {
        let transport = ProviderHTTPTransportStub { request in
            #expect(request.url?.host == "www.krill-ai.net")
            #expect(request.url?.path == "/api/request-logs/stats")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test.jwt.value")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.timeoutInterval == 15)

            let body = try #require(request.httpBody)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(object["start_time"] as? String == "2027-01-15T08:00:00Z")
            #expect(object["end_time"] as? String == "2027-01-15T09:00:00Z")
            return Self.response(
                for: request,
                body: #"{"success":true,"data":{"total_requests":0}}"#)
        }
        let client = KrillAPIClient(transport: transport)

        _ = try await client.fetchStats(
            jwt: "test.jwt.value",
            startTime: Date(timeIntervalSince1970: 1_800_000_000),
            endTime: Date(timeIntervalSince1970: 1_800_003_600))
    }

    @Test
    func `rejects non 200 status and invalid JSON`() async {
        let statusTransport = ProviderHTTPTransportStub { request in
            Self.response(for: request, status: 204, body: "{}")
        }
        await #expect(throws: KrillAPIError.httpStatus(204)) {
            _ = try await KrillAPIClient(transport: statusTransport).fetchCredits(jwt: "test.jwt.value")
        }

        let invalidTransport = ProviderHTTPTransportStub { request in
            Self.response(for: request, body: "not-json")
        }
        await #expect(throws: KrillAPIError.invalidResponse("/api/credits")) {
            _ = try await KrillAPIClient(transport: invalidTransport).fetchCredits(jwt: "test.jwt.value")
        }

        let unsuccessfulTransport = ProviderHTTPTransportStub { request in
            Self.response(for: request, body: #"{"success":false,"data":{"balance_usd":"99"}}"#)
        }
        await #expect(throws: KrillAPIError.invalidResponse("/api/credits")) {
            _ = try await KrillAPIClient(transport: unsuccessfulTransport).fetchCredits(jwt: "test.jwt.value")
        }
    }

    @Test(arguments: [
        (401, KrillAPIError.authenticationRequired(401)),
        (403, KrillAPIError.authenticationRequired(403)),
        (429, KrillAPIError.rateLimited),
        (503, KrillAPIError.serverError(503)),
    ])
    func `classifies actionable HTTP failures`(status: Int, expected: KrillAPIError) async {
        let transport = ProviderHTTPTransportStub { request in
            Self.response(for: request, status: status, body: "{}")
        }

        await #expect(throws: expected) {
            _ = try await KrillAPIClient(transport: transport).fetchCredits(jwt: "test.jwt.value")
        }
    }

    @Test
    func `preserves transport cancellation`() async {
        let transport = ProviderHTTPTransportStub { _ in throw URLError(.cancelled) }

        await #expect(throws: CancellationError.self) {
            _ = try await KrillAPIClient(transport: transport).fetchCredits(jwt: "test.jwt.value")
        }
    }

    @Test
    func `exposes canonical Krill web endpoints`() {
        #expect(KrillAPIClient.baseURL.absoluteString == "https://www.krill-ai.net")
        #expect(KrillAPIClient.loginURL.absoluteString == "https://www.krill-ai.net/login")
        #expect(KrillAPIClient.dashboardURL.absoluteString == "https://www.krill-ai.net/app")
    }

    private static func response(
        for request: URLRequest,
        status: Int = 200,
        body: String) -> (Data, URLResponse)
    {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil)!
        return (Data(body.utf8), response)
    }
}
