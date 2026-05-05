#if os(macOS)
import Foundation
import Testing
@testable import TokenBarCore

struct KrillCostUsageFetcherTests {
    @Test
    func `builds cost entry from Krill stats response`() throws {
        let json = """
        {
          "success": true,
          "data": {
            "total_requests": 12,
            "success_requests": 11,
            "failed_requests": 1,
            "input_tokens": 1000,
            "output_tokens": 250,
            "cache_creation_input_tokens": 30,
            "cache_read_input_tokens": 70,
            "reasoning_tokens": 15,
            "total_tokens": 1350,
            "total_cost_usd": "0.123456789",
            "range_start": "2026-05-04T00:00:00Z",
            "range_end": "2026-05-05T00:00:00Z",
            "bucket_seconds": 3600,
            "trend": []
          }
        }
        """
        let response = try JSONDecoder().decode(KrillStatsResponse.self, from: Data(json.utf8))
        let stats = try #require(response.data)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)))

        let entry = try #require(KrillCostUsageFetcher.entry(dayStart: day, stats: stats, calendar: calendar))

        #expect(entry.date == "2026-05-04")
        #expect(entry.inputTokens == 1000)
        #expect(entry.outputTokens == 250)
        #expect(entry.cacheCreationTokens == 30)
        #expect(entry.cacheReadTokens == 70)
        #expect(entry.totalTokens == 1350)
        #expect(abs((entry.costUSD ?? 0) - 0.123456789) < 0.000000001)
        #expect(entry.modelBreakdowns == nil)
    }

    @Test
    func `ignores empty Krill stats day`() throws {
        let json = """
        {
          "success": true,
          "data": {
            "total_requests": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "total_cost_usd": "0"
          }
        }
        """
        let response = try JSONDecoder().decode(KrillStatsResponse.self, from: Data(json.utf8))
        let stats = try #require(response.data)

        #expect(KrillCostUsageFetcher.entry(dayStart: Date(), stats: stats) == nil)
    }

    @Test
    func `builds chart entries from adaptive Krill trend buckets`() throws {
        let json = """
        {
          "success": true,
          "data": {
            "total_requests": 3,
            "total_tokens": 600,
            "total_cost_usd": "0.06",
            "trend": [
              {
                "bucket_start": "2026-05-03T23:30:00Z",
                "request_count": 1,
                "total_tokens": 100,
                "total_cost_usd": "0.01"
              },
              {
                "bucket_start": "2026-05-04T01:00:00Z",
                "request_count": 2,
                "total_tokens": 500,
                "total_cost_usd": "0.05"
              },
              {
                "bucket_start": "2026-05-05T01:00:00Z",
                "request_count": 0,
                "total_tokens": 0,
                "total_cost_usd": "0"
              }
            ]
          }
        }
        """
        let response = try JSONDecoder().decode(KrillStatsResponse.self, from: Data(json.utf8))
        let stats = try #require(response.data)
        let trend = try #require(stats.trend)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let entries = KrillCostUsageFetcher.entries(from: trend, calendar: calendar)

        #expect(entries.count == 2)
        #expect(entries[0].date == "2026-05-03")
        #expect(entries[0].totalTokens == 100)
        #expect(abs((entries[0].costUSD ?? 0) - 0.01) < 0.000000001)
        #expect(entries[1].date == "2026-05-04")
        #expect(entries[1].totalTokens == 500)
        #expect(abs((entries[1].costUSD ?? 0) - 0.05) < 0.000000001)
    }

    @Test
    func `builds active quota provider cost from Krill subscription quota`() throws {
        let json = """
        {
          "success": true,
          "data": {
            "subscriptions": [
              {
                "subscription_id": 505,
                "plan_name": "🦞 尊享月卡",
                "items": [
                  {
                    "date": "2026-04-10",
                    "daily_limit_usd": "0.000000",
                    "used_usd": "0.000000",
                    "forwarded_limit_usd": "0.000000",
                    "forwarded_used_usd": "0.000000"
                  }
                ]
              },
              {
                "subscription_id": 1150,
                "plan_name": "Elite",
                "items": [
                  {
                    "date": "2026-04-29",
                    "daily_limit_usd": "10.000000",
                    "used_usd": "4.000000",
                    "forwarded_limit_usd": "2.000000",
                    "forwarded_used_usd": "1.000000"
                  },
                  {
                    "date": "2026-04-30",
                    "daily_limit_usd": "439.990000",
                    "used_usd": "299.623684",
                    "forwarded_limit_usd": "0.000000",
                    "forwarded_used_usd": "0.000000"
                  }
                ]
              }
            ]
          }
        }
        """
        let response = try JSONDecoder().decode(
            KrillActiveSubscriptionDailyQuotaResponse.self,
            from: Data(json.utf8))
        let cost = try #require(KrillUsageFetcher.activeQuotaProviderCost(from: response))

        #expect(abs(cost.used - 299.623684) < 0.000001)
        #expect(abs(cost.limit - 439.99) < 0.000001)
        #expect(cost.currencyCode == "USD")
        #expect(cost.period == "Elite #1150")
    }
}
#endif
