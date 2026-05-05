#if os(macOS)
import AppKit
import Foundation
import Testing
import TokenBarCore
@testable import TokenBar

@MainActor
struct MenuDescriptorKrillTests {
    @Test
    func `krill quota details do not render as reset lines`() throws {
        let suite = "MenuDescriptorKrillTests-quota-details"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false
        settings.usageBarsShowUsed = false

        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
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
            tertiary: nil,
            updatedAt: Date(),
            identity: ProviderIdentitySnapshot(
                providerID: .krill,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "Wallet: $16.55\nKrill · Elite today $297.37/$439.99"))
        store._setSnapshotForTesting(snapshot, provider: .krill)

        let descriptor = MenuDescriptor.build(
            provider: .krill,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false,
            includeContextualActions: false)

        let textLines = descriptor.sections
            .flatMap(\.entries)
            .compactMap { entry -> String? in
                guard case let .text(text, _) = entry else { return nil }
                return text
            }

        #expect(textLines.contains("Elite Credits: 32% left"))
        #expect(textLines.contains("Elite 14261/43999 credits remaining"))
        #expect(textLines.contains("尊享月卡 Requests: 99% left"))
        #expect(textLines.contains("尊享月卡 1890/200000 requests this month"))
        #expect(!textLines.contains(where: { $0.contains("Resets Elite") }))
        #expect(!textLines.contains(where: { $0.contains("Resets 尊享月卡") }))
    }

    @Test
    func `krill menu card exposes active quota and token cost`() throws {
        let suite = "MenuDescriptorKrillTests-active-quota-cost"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false
        settings.costUsageEnabled = true
        settings.showOptionalCreditsAndExtraUsage = true

        let fetcher = UsageFetcher(environment: [:])
        let store = UsageStore(
            fetcher: fetcher,
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let now = Date(timeIntervalSince1970: 1_777_777_777)
        store._setSnapshotForTesting(UsageSnapshot(
            primary: nil,
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(
                used: 299.623684,
                limit: 439.99,
                currencyCode: "USD",
                period: "Elite #1150",
                updatedAt: now),
            updatedAt: now,
            identity: ProviderIdentitySnapshot(
                providerID: .krill,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "Wallet: $16.55\nKrill")), provider: .krill)
        store._setTokenSnapshotForTesting(CostUsageTokenSnapshot(
            sessionTokens: 843_000,
            sessionCostUSD: 1.4607,
            last30DaysTokens: 843_000,
            last30DaysCostUSD: 406.581746,
            daily: [CostUsageDailyReport.Entry(
                date: "2026-05-05",
                inputTokens: nil,
                outputTokens: nil,
                totalTokens: 843_000,
                costUSD: 1.4607,
                modelsUsed: nil,
                modelBreakdowns: nil)],
            updatedAt: now), provider: .krill)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: self.makeStatusBarForTesting())

        let model = try #require(controller.menuCardModel(for: .krill))

        #expect(model.providerCost?.title == "Active quota")
        #expect(model.providerCost?.spendLine == "Elite #1150: $299.62 / $439.99")
        #expect(model.tokenUsage?.sessionLine == "Today: $1.46 · 843K tokens")
        #expect(model.tokenUsage?.monthLine == "Last 30 days: $406.58 · 843K tokens")
    }

    private func makeStatusBarForTesting() -> NSStatusBar {
        let env = ProcessInfo.processInfo.environment
        if env["GITHUB_ACTIONS"] == "true" || env["CI"] == "true" {
            return .system
        }
        return NSStatusBar()
    }
}
#endif
