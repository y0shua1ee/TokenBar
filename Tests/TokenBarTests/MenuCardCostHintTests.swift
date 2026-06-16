import Foundation
import Testing
import TokenBarCore
@testable import TokenBar

struct MenuCardCostHintTests {
    @Test
    func `claude cost hint explains cache tokens and status line drift`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 123,
            sessionCostUSD: 1.23,
            last30DaysTokens: 456,
            last30DaysCostUSD: 78.9,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-05-14",
                    inputTokens: 1,
                    outputTokens: 2,
                    cacheReadTokens: 300,
                    cacheCreationTokens: 400,
                    totalTokens: 703,
                    costUSD: 1.23,
                    modelsUsed: ["claude-sonnet-4-6"],
                    modelBreakdowns: nil),
            ],
            updatedAt: now)
        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
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
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.tokenUsage?.hintLine?.contains("cache read/write tokens") == true)
        #expect(model.tokenUsage?.hintLine?.contains("Claude Code /status") == true)
    }

    @Test
    func `one day history label stays today`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 120,
            sessionCostUSD: 1.2,
            last30DaysTokens: 120,
            last30DaysCostUSD: 1.2,
            historyDays: 1,
            daily: [
                .init(
                    date: "2026-05-14",
                    inputTokens: 100,
                    outputTokens: 20,
                    totalTokens: 120,
                    costUSD: 1.2,
                    modelsUsed: ["claude-sonnet-4-6"],
                    modelBreakdowns: nil),
            ],
            updatedAt: now)
        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
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
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.tokenUsage?.monthLine.hasPrefix("Today: ") == true)
    }

    @Test
    func `openrouter cost history suppresses provider fetch error in header`() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let now = updatedAt.addingTimeInterval(90)
        let metadata = try #require(ProviderDefaults.metadata[.openrouter])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .openrouter,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: Self.costSnapshot(updatedAt: updatedAt, requests: 3),
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: "No available fetch strategy for openrouter.",
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.subtitleStyle == .info)
        #expect(model.subtitleText == UsageFormatter.updatedString(from: updatedAt, now: now))
        #expect(model.subtitleText.contains("fetch strategy") == false)
        #expect(model.tokenUsage?.sessionLine == "Latest day: $0.03 · 46K tokens · 3 requests")
        #expect(model.tokenUsage?.monthLine == "Last 30 completed days: $7.99 · 4.8M tokens · 3 requests")
    }

    @Test
    func `krill cost history suppresses quota fetch error in header`() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let now = updatedAt.addingTimeInterval(90)
        let metadata = try #require(ProviderDefaults.metadata[.krill])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .krill,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: Self.costSnapshot(updatedAt: updatedAt, requests: nil),
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: "Krill API HTTP 400",
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.subtitleStyle == .info)
        #expect(model.subtitleText == UsageFormatter.updatedString(from: updatedAt, now: now))
        #expect(model.subtitleText.contains("HTTP 400") == false)
        #expect(model.tokenUsage?.sessionLine == "Today: $0.03 · 46K tokens")
        #expect(model.tokenUsage?.monthLine == "Last 30 days: $7.99 · 4.8M tokens")
    }

    @Test
    func `openrouter provider error remains visible without cost history`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.openrouter])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .openrouter,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: "No available fetch strategy for openrouter.",
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.subtitleStyle == .error)
        #expect(model.subtitleText == "No available fetch strategy for openrouter.")
        #expect(model.tokenUsage == nil)
    }

    private static func costSnapshot(updatedAt: Date, requests: Int?) -> CostUsageTokenSnapshot {
        CostUsageTokenSnapshot(
            sessionTokens: 46000,
            sessionCostUSD: 0.03,
            sessionRequests: requests,
            last30DaysTokens: 4_800_000,
            last30DaysCostUSD: 7.99,
            last30DaysRequests: requests,
            daily: [
                .init(
                    date: "2026-06-15",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: 46000,
                    requestCount: requests,
                    costUSD: 0.03,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: updatedAt)
    }
}
