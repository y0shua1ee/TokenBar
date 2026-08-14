import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct OpenRouterSpendDashboardTests {
    @Test
    func `completed UTC window survives a Tokyo local day boundary`() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-01T16:00:00Z"))
        let june1 = try #require(tokyo.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let june30 = try #require(tokyo.date(from: DateComponents(year: 2026, month: 6, day: 30)))
        let july1 = try #require(tokyo.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let entries = (1...30).map { day in
            Self.entry(day: String(format: "2026-06-%02d", day))
        }
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 10,
            sessionCostUSD: 1,
            last30DaysTokens: 300,
            last30DaysCostUSD: 30,
            historyDays: 30,
            daily: entries,
            updatedAt: now)
        let input = SpendDashboardModel.ProviderInput(
            provider: .openrouter,
            displayName: "OpenRouter",
            snapshot: snapshot)

        let thirtyDays = try #require(SpendDashboardModel.build(
            inputs: [input],
            requestedDays: 30,
            now: now,
            calendar: tokyo).groups.first)
        let oneDay = try #require(SpendDashboardModel.build(
            inputs: [input],
            requestedDays: 1,
            now: now,
            calendar: tokyo).groups.first)

        #expect(thirtyDays.totalCost == 30)
        #expect(thirtyDays.totalTokens == 300)
        #expect(thirtyDays.coveredDayCount == 30)
        #expect(thirtyDays.dailyPoints.first?.day == june1)
        #expect(thirtyDays.dailyPoints.last?.day == june30)
        #expect(thirtyDays.chartDomain == june1...july1)

        #expect(oneDay.totalCost == 1)
        #expect(oneDay.totalTokens == 10)
        #expect(oneDay.coveredDayCount == 1)
        #expect(oneDay.dailyPoints.map(\.day) == [june30])
        #expect(oneDay.chartDomain == june30...july1)
    }

    private static func entry(day: String) -> CostUsageDailyReport.Entry {
        CostUsageDailyReport.Entry(
            date: day,
            inputTokens: 10,
            outputTokens: 0,
            totalTokens: 10,
            costUSD: 1,
            modelsUsed: ["test-model"],
            modelBreakdowns: [.init(modelName: "test-model", costUSD: 1, totalTokens: 10)])
    }
}
