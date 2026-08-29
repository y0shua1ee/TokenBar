import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct MenuCardStaleTimingTests {
    @Test
    func `stale codex snapshot hides reset and pace timing until refresh`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "user@example.com",
            accountOrganization: nil,
            loginMethod: "Pro")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 2,
                windowMinutes: 300,
                resetsAt: now.addingTimeInterval(-60),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 4,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(2 * 24 * 60 * 60),
                resetDescription: nil),
            tertiary: nil,
            extraRateWindows: [
                NamedRateWindow(
                    id: "codex-spark",
                    title: "Codex Spark 5-hour",
                    window: RateWindow(
                        usedPercent: 0,
                        windowMinutes: 300,
                        resetsAt: now.addingTimeInterval(-60),
                        resetDescription: nil)),
                NamedRateWindow(
                    id: "codex-spark-weekly",
                    title: "Codex Spark Weekly",
                    window: RateWindow(
                        usedPercent: 0,
                        windowMinutes: 10080,
                        resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60),
                        resetDescription: nil)),
            ],
            updatedAt: now.addingTimeInterval(-86400),
            identity: identity)
        let projection = CodexConsumerProjection.make(
            surface: .liveCard,
            context: CodexConsumerProjection.Context(
                snapshot: snapshot,
                rawUsageError: nil,
                liveCredits: nil,
                rawCreditsError: nil,
                liveDashboard: nil,
                rawDashboardError: nil,
                dashboardAttachmentAuthorized: false,
                dashboardRequiresLogin: false,
                now: now))

        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: snapshot,
            codexProjection: projection,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "user@example.com", plan: "Pro"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            rateLimitTimingIsStale: true,
            now: now))

        for id in ["primary", "secondary", "codex-spark", "codex-spark-weekly"] {
            let metric = try #require(model.metrics.first { $0.id == id })
            #expect(metric.resetText == nil)
            #expect(metric.detailLeftText == nil)
            #expect(metric.detailRightText == nil)
            #expect(metric.pacePercent == nil)
        }
    }
}
