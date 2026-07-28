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
        #expect(firstDay.requestCount == 300)
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
        #expect(tokenSnapshot.currencyCode == "CNY")
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

    @Test
    func `converts dashboard data to web usage without fabricating balance`() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_777_777_777)
        let dashboard = try DeepSeekDashboardUsageFetcher._parseSnapshotForTesting(
            costData: Data(Self.costJSON.utf8),
            amountData: Data(Self.amountJSON.utf8),
            now: updatedAt)
        let today = try #require(ISO8601DateFormatter().date(from: "2026-05-02T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        let usage = dashboard.toUsageSnapshot(now: today, calendar: calendar)
        let summary = try #require(usage.deepseekUsage)

        #expect(usage.primary == nil)
        #expect(usage.secondary == nil)
        #expect(usage.identity?.providerID == .deepseek)
        #expect(usage.identity?.loginMethod == "web")
        #expect(summary.todayTokens == 40_118_189)
        #expect(summary.currentMonthTokens == 65_118_189)
        #expect(summary.todayCost == 7.20)
        #expect(summary.currentMonthCost == 12.32)
        #expect(summary.requestCount == 360)
        #expect(summary.currentMonthRequestCount == 660)
        #expect(summary.topModel == "deepseek-v4-pro")
        #expect(summary.categoryBreakdown == [
            DeepSeekCategoryBreakdown(category: .promptCacheHitToken, tokens: 20_000_000, cost: nil),
            DeepSeekCategoryBreakdown(category: .promptCacheMissToken, tokens: 30_000_000, cost: nil),
            DeepSeekCategoryBreakdown(category: .responseToken, tokens: 15_118_189, cost: nil),
        ])
        #expect(summary.daily.map(\.requestCount) == [300, 360])
    }

    @Test
    func `dashboard summary selects the dominant model across multiple models`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dashboard = DeepSeekDashboardUsageSnapshot(
            currencyCode: "CNY",
            monthlyCost: 3,
            requestCount: 3,
            totalTokens: 300,
            models: ["deepseek-chat", "deepseek-reasoner"],
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2027-01-15",
                    inputTokens: 120,
                    outputTokens: 180,
                    cacheReadTokens: nil,
                    cacheCreationTokens: nil,
                    totalTokens: 300,
                    requestCount: 3,
                    costUSD: 3,
                    modelsUsed: ["deepseek-chat", "deepseek-reasoner"],
                    modelBreakdowns: [
                        .init(modelName: "deepseek-chat", costUSD: 1, totalTokens: 200),
                        .init(modelName: "deepseek-reasoner", costUSD: 2, totalTokens: 100),
                    ]),
            ],
            updatedAt: now)

        let summary = dashboard.toUsageSummary(now: now)

        #expect(summary.topModel == "deepseek-reasoner")
        #expect(summary.categoryBreakdown.map(\.category) == [.promptCacheMissToken, .responseToken])
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
