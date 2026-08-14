import Foundation
import Testing
@testable import CodexBarCore

struct KrillUsageFetcherTests {
    @Test
    func `descriptor excludes unsupported widget and API debug surfaces`() {
        let descriptor = KrillProviderDescriptor.descriptor

        #expect(!descriptor.metadata.widgetSelectable)
        #expect(descriptor.credentials?.apiKeyDebugLabel == nil)
        #expect(descriptor.tokenCost.estimateDisclaimer == "Reported by Krill usage API.")
    }

    @Test
    func `builds wallet subscription and active quota snapshot`() throws {
        let credits = try Self.decode(KrillCreditsResponse.self, #"{"success":true,"data":{"balance_usd":"16.55"}}"#)
        let subscription = try Self.decode(KrillSubscriptionResponse.self, #"""
        {
          "success": true,
          "data": {
            "credit_balance_usd": "12.34",
            "request_count_quota": {"limit_monthly": 200000, "used_monthly": 1890},
            "subscriptions": [
              {"subscription_id": 1150, "plan": {"name": "Elite"},
               "quota": {"limit_credits": 440, "used_credits": 10, "remaining_credits": 140,
                         "daily_limit_usd": "439.99", "used_usd": "297.37"}},
              {"subscription_id": 505, "plan": {"name": "尊享月卡"}, "quota": {}}
            ]
          }
        }
        """#)
        let active = try Self.decode(KrillActiveSubscriptionDailyQuotaResponse.self, #"""
        {"success":true,"data":{"subscriptions":[
          {"subscription_id":1150,"plan_name":"Elite","items":[
            {"date":"2026-04-29","daily_limit_usd":"10","used_usd":"4",
             "forwarded_limit_usd":"2","forwarded_used_usd":"1"},
            {"date":"2026-04-30","daily_limit_usd":"439.99","used_usd":"299.623684",
             "forwarded_limit_usd":"0","forwarded_used_usd":"0"}
          ]}
        ]}}
        """#)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let snapshot = KrillUsageFetcher.buildSnapshot(
            credits: credits,
            subscription: subscription,
            stats: nil,
            activeQuota: active,
            modelCount: nil,
            now: now)

        #expect(snapshot.primary?.usedPercent == 300.0 / 440.0 * 100.0)
        #expect(snapshot.primary?.resetDescription == "Elite 140/440 credits remaining")
        #expect(snapshot.secondary?.resetDescription == "尊享月卡 1890/200000 requests this month")
        #expect(snapshot.identity?.loginMethod == "Web")
        #expect(snapshot.details.first?.rows.contains { $0.label == "Wallet" && $0.value == "$16.55" } == true)
        #expect(snapshot.details.first?.rows.contains {
            $0.label == "Elite quota" && $0.value == "$297.37 / $439.99"
        } == true)
        #expect(snapshot.providerCost?.used == 299.623684)
        #expect(snapshot.providerCost?.limit == 439.99)
        #expect(snapshot.providerCost?.period == "Elite #1150")
        #expect(snapshot.updatedAt == now)
    }

    @Test
    func `required endpoints allow one success and optional failures`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/credits":
                Self.response(for: request, body: #"{"success":true,"data":{"balance_usd":"7.25"}}"#)
            case "/api/subscription":
                Self.response(for: request, status: 503, body: "{}")
            default:
                throw URLError(.notConnectedToInternet)
            }
        }

        let result = try await KrillUsageFetcher(transport: transport).fetchUsage(jwt: jwt, now: now)

        #expect(result.credits?.remaining == 7.25)
        #expect(result.usage.identity?.loginMethod == "Web")
        #expect(result.usage.details.first?.rows.contains {
            $0.label == "Wallet" && $0.value == "$7.25"
        } == true)
        #expect(await transport.requests().count == 5)
    }

    @Test
    func `disabled optional usage only requests core account endpoints`() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/credits":
                Self.response(for: request, body: #"{"success":true,"data":{"balance_usd":"7.25"}}"#)
            case "/api/subscription":
                Self.response(for: request, body: #"{"success":true,"data":{"subscriptions":[]}}"#)
            default:
                Self.response(for: request, status: 500, body: "{}")
            }
        }

        let result = try await KrillUsageFetcher(transport: transport).fetchUsage(
            jwt: jwt,
            now: now,
            includeOptionalUsage: false)
        let paths = await transport.requests().compactMap { $0.url?.path }

        #expect(result.credits?.remaining == 7.25)
        #expect(paths == ["/api/credits", "/api/subscription"])
    }

    @Test
    func `optional endpoint cancellation is never swallowed`() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let jwt = KrillJWTTests.token(expiration: now.timeIntervalSince1970 + 3600, subject: "account")
        let transport = ProviderHTTPTransportStub { request in
            switch request.url?.path {
            case "/api/credits":
                Self.response(for: request, body: #"{"success":true,"data":{"balance_usd":"7.25"}}"#)
            case "/api/subscription":
                Self.response(for: request, body: #"{"success":true,"data":{"subscriptions":[]}}"#)
            case "/api/request-logs/stats":
                throw URLError(.cancelled)
            default:
                Self.response(for: request, body: #"{"success":true,"data":[]}"#)
            }
        }

        await #expect(throws: CancellationError.self) {
            _ = try await KrillUsageFetcher(transport: transport).fetchUsage(jwt: jwt, now: now)
        }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, _ value: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(value.utf8))
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
