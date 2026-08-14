import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct MenuDescriptorKrillTests {
    @Test
    func `descriptor keeps web login separate from API fetch sources`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .krill)
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 67.59,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Elite 14261/43999 credits remaining"),
            secondary: RateWindow(
                usedPercent: 0.945,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "尊享月卡 1890/200000 requests this month"),
            updatedAt: Date())

        #expect(descriptor.fetchPlan.sourceModes.map(\.rawValue) == ["auto", "api"])
        #expect(descriptor.tokenCost.supportsTokenCost)
        #expect(descriptor.tokenCost.supportsTokenSnapshot)
        #expect(!descriptor.cli.supportsCostCommand)
        #expect(descriptor.presentation.menuCard.supportsInlineTokenCostDashboard)
        #expect(descriptor.presentation.menuCard.usesRawPrimaryResetDescription)
        #expect(descriptor.presentation.menu.usesPrimaryDescriptionAsDetail(snapshot: snapshot))
        #expect(descriptor.presentation.menu.secondaryDescriptionMode == .resetOverride)
    }

    @Test
    func `menu card renders active quota and token cost`() throws {
        let now = Date(timeIntervalSince1970: 1_777_777_777)
        let metadata = try #require(ProviderDefaults.metadata[.krill])
        let usage = UsageSnapshot(
            primary: nil,
            secondary: nil,
            providerCost: ProviderCostSnapshot(
                used: 299.623684,
                limit: 439.99,
                currencyCode: "USD",
                period: "Elite #1150",
                updatedAt: now),
            updatedAt: now,
            identity: ProviderIdentitySnapshot(
                providerID: UsageProvider.krill.instanceID,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "Web"))
        let tokenUsage = CostUsageTokenSnapshot(
            sessionTokens: 843_000,
            sessionCostUSD: 1.4607,
            last30DaysTokens: 843_000,
            last30DaysCostUSD: 406.581746,
            daily: [.init(
                date: "2026-05-05",
                inputTokens: nil,
                outputTokens: nil,
                totalTokens: 843_000,
                costUSD: 1.4607,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            updatedAt: now)

        let model = UsageMenuCardView.Model.make(.init(
            provider: .krill,
            metadata: metadata,
            snapshot: usage,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: tokenUsage,
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

        #expect(model.providerCost?.title == "Active quota")
        #expect(model.providerCost?.spendLine == "Elite #1150: $299.62 / $439.99")
        #expect(model.tokenUsage?.sessionLine == "Today: $1.46 · 843K tokens")
        #expect(model.tokenUsage?.monthLine == "Last 30 days: $406.58 · 843K tokens")
    }
}
