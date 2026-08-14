import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct OpenRouterMenuCardTests {
    @Test
    func `activity cost section labels latest completed UTC day`() throws {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 30,
            sessionCostUSD: 23.45,
            last30DaysTokens: 50,
            last30DaysCostUSD: 56.78,
            historyDays: 30,
            historyLabel: "Last 30 completed UTC days",
            daily: [
                Self.entry(day: "not-a-day", cost: 99, tokens: 99),
                Self.entry(day: "2026-05-12", cost: 12.34, tokens: 20),
                Self.entry(day: "2026-05-13", cost: 23.45, tokens: 30),
            ],
            updatedAt: Date())

        let section = try #require(Self.model(snapshot: snapshot).tokenUsage)

        #expect(section.sessionLine == "Latest completed UTC day (May 13): $23.45 · 30 tokens")
        #expect(section.sessionLine.contains("Today") == false)
        #expect(section.sessionLine.contains("billing") == false)
        #expect(section.monthLine == "Last 30 completed UTC days: $56.78 · 50 tokens")
    }

    @Test
    func `one day activity fallback never claims today`() throws {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: 1,
            last30DaysTokens: nil,
            last30DaysCostUSD: 1,
            historyDays: 1,
            daily: [],
            updatedAt: Date())

        let section = try #require(Self.model(snapshot: snapshot).tokenUsage)

        #expect(section.sessionLine == "Latest completed UTC day: $1.00")
        #expect(section.monthLine == "Latest completed UTC day: $1.00")
        #expect(section.sessionLine.contains("Today") == false)
        #expect(section.monthLine.contains("Today") == false)
    }

    @Test(arguments: ["UTC", "Asia/Tokyo"])
    func `completed UTC comparisons ignore the local current day`(timeZoneID: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        let snapshot = try Self.comparisonSnapshot()

        let summaries = UsageMenuCardView.Model.costComparisonSummaries(
            provider: .openrouter,
            snapshot: snapshot,
            calendar: calendar)

        #expect(summaries.map(\.days) == [7, 30])
        #expect(summaries.map(\.totalCostUSD) == [5, 6])
        #expect(summaries.map(\.totalTokens) == [50, 60])
        #expect(
            UsageMenuCardView.Model.costComparisonSummaries(
                provider: .claude,
                snapshot: snapshot,
                calendar: calendar) == snapshot.comparisonSummaries(calendar: calendar))
    }

    @Test
    func `menu and inline comparisons end at the latest completed UTC day`() throws {
        let model = try Self.model(
            snapshot: Self.comparisonSnapshot(),
            comparisonPeriodsEnabled: true)
        let tokenUsage = try #require(model.tokenUsage)
        let dashboard = try #require(model.inlineUsageDashboard)
        let expected = [
            "Last 7 days: $5.00 · 50 tokens",
            "Last 30 days: $6.00 · 60 tokens",
        ]

        #expect(tokenUsage.comparisonLines == expected)
        #expect(Array(dashboard.detailLines.prefix(2)) == expected)
    }

    private static func model(
        snapshot: CostUsageTokenSnapshot,
        comparisonPeriodsEnabled: Bool = false) throws -> UsageMenuCardView.Model
    {
        let metadata = try #require(ProviderDefaults.metadata[.openrouter])
        return UsageMenuCardView.Model.make(.init(
            provider: .openrouter,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: snapshot,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true,
            costComparisonPeriodsEnabled: comparisonPeriodsEnabled,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: snapshot.updatedAt))
    }

    private static func comparisonSnapshot() throws -> CostUsageTokenSnapshot {
        try CostUsageTokenSnapshot(
            sessionTokens: 30,
            sessionCostUSD: 3,
            last30DaysTokens: 60,
            last30DaysCostUSD: 6,
            historyDays: 90,
            historyLabel: "Last 90 completed UTC days",
            daily: [
                self.entry(day: "2026-06-01", cost: 1, tokens: 10),
                self.entry(day: "2026-06-24", cost: 2, tokens: 20),
                self.entry(day: "2026-06-30", cost: 3, tokens: 30),
                self.entry(day: "2026-07-01", cost: 100, tokens: 1000),
            ],
            updatedAt: #require(ISO8601DateFormatter().date(from: "2026-07-01T16:00:00Z")))
    }

    private static func entry(day: String, cost: Double, tokens: Int) -> CostUsageDailyReport.Entry {
        CostUsageDailyReport.Entry(
            date: day,
            inputTokens: tokens,
            outputTokens: 0,
            totalTokens: tokens,
            costUSD: cost,
            modelsUsed: ["test-model"],
            modelBreakdowns: nil)
    }
}
