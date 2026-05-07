import Foundation
import Testing
@testable import TokenBarCore

struct DeepSeekDashboardUsageFetcherTests {
    @Test
    func `parses dashboard cost and amount payloads`() throws {
        let now = Date(timeIntervalSince1970: 1_777_777_777)
        let snapshot = try DeepSeekDashboardUsageFetcher._parseSnapshotForTesting(
            costData: Data(Self.costJSON.utf8),
            amountData: Data(Self.amountJSON.utf8),
            now: now)

        #expect(snapshot.currencyCode == "CNY")
        #expect(abs(snapshot.monthlyCost - 12.32) < 0.0001)
        #expect(snapshot.requestCount == 660)
        #expect(snapshot.totalTokens == 65_118_189)
        #expect(snapshot.models == ["deepseek-v4-pro"])
        #expect(snapshot.daily.count == 2)

        let firstDay = try #require(snapshot.daily.first)
        #expect(firstDay.date == "2026-05-01")
        #expect(firstDay.costUSD == 5.12)
        #expect(firstDay.totalTokens == 25_000_000)
        #expect(firstDay.modelBreakdowns?.first?.modelName == "deepseek-v4-pro")
        #expect(firstDay.modelBreakdowns?.first?.costUSD == 5.12)
        #expect(firstDay.modelBreakdowns?.first?.totalTokens == 25_000_000)
    }

    @Test
    func `converts dashboard snapshot to currency aware token snapshot`() throws {
        let now = Date(timeIntervalSince1970: 1_777_777_777)
        let dashboard = try DeepSeekDashboardUsageFetcher._parseSnapshotForTesting(
            costData: Data(Self.costJSON.utf8),
            amountData: Data(Self.amountJSON.utf8),
            now: now)

        let tokenSnapshot = dashboard.toTokenSnapshot(now: now)

        #expect(abs((tokenSnapshot.last30DaysCostUSD ?? 0) - 12.32) < 0.0001)
        #expect(tokenSnapshot.costCurrencyCode == "CNY")
        #expect(tokenSnapshot.last30DaysTokens == 65_118_189)
        #expect(tokenSnapshot.last30DaysRequests == 660)
        #expect(tokenSnapshot.daily.count == 2)
        #expect(tokenSnapshot.sessionTokens == 40_118_189)
        #expect(abs((tokenSnapshot.sessionCostUSD ?? 0) - 7.20) < 0.0001)
    }

    @Test
    func `converts dashboard snapshot to monthly spend provider cost without balance denominator`() throws {
        let now = Date(timeIntervalSince1970: 1_777_777_777)
        let dashboard = try DeepSeekDashboardUsageFetcher._parseSnapshotForTesting(
            costData: Data(Self.costJSON.utf8),
            amountData: Data(Self.amountJSON.utf8),
            now: now)

        let cost = try #require(dashboard.toProviderCost())

        #expect(abs(cost.used - 12.32) < 0.0001)
        #expect(abs(cost.limit - 12.32) < 0.0001)
        #expect(abs(cost.limit - 57.52) > 0.0001)
        #expect(cost.currencyCode == "CNY")
        #expect(cost.period == "This month")
    }

    private static let costJSON = """
    {
      "data": {
        "biz_data": [
          {
            "currency": "CNY",
            "total": [
            {
              "model": "deepseek-v4-pro",
              "usage": [
                { "type": "TOTAL", "amount": "12.32", "currency": "CNY" }
              ]
            }
          ],
          "days": [
            {
              "date": "2026-5-1",
              "data": [
                {
                  "model": "deepseek-v4-pro",
                  "usage": [
                    { "type": "TOTAL", "amount": "5.12", "currency": "CNY" }
                  ]
                }
              ]
            },
            {
              "date": "2026-5-2",
              "data": [
                {
                  "model": "deepseek-v4-pro",
                  "usage": [
                    { "type": "TOTAL", "amount": 7.20, "currency": "CNY" }
                  ]
                }
              ]
            }
          ]
          }
        ]
      }
    }
    """

    private static let amountJSON = """
    {
      "data": {
        "biz_data": {
          "total": [
            {
              "model": "deepseek-v4-pro",
              "usage": [
                { "type": "REQUEST", "amount": "660" },
                { "type": "RESPONSE_TOKEN", "amount": 15118189 },
                { "type": "PROMPT_CACHE_MISS_TOKEN", "amount": "30000000" },
                { "type": "PROMPT_CACHE_HIT_TOKEN", "amount": "20000000" }
              ]
            }
          ],
          "days": [
            {
              "date": "2026-5-1",
              "data": [
                {
                  "model": "deepseek-v4-pro",
                  "usage": [
                    { "type": "REQUEST", "amount": "300" },
                    { "type": "RESPONSE_TOKEN", "amount": 1000000 },
                    { "type": "PROMPT_CACHE_MISS_TOKEN", "amount": "14000000" },
                    { "type": "PROMPT_CACHE_HIT_TOKEN", "amount": "10000000" }
                  ]
                }
              ]
            },
            {
              "date": "2026-5-2",
              "data": [
                {
                  "model": "deepseek-v4-pro",
                  "usage": [
                    { "type": "REQUEST", "amount": "360" },
                    { "type": "RESPONSE_TOKEN", "amount": 14118189 },
                    { "type": "PROMPT_CACHE_MISS_TOKEN", "amount": "16000000" },
                    { "type": "PROMPT_CACHE_HIT_TOKEN", "amount": "10000000" }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
    """
}
