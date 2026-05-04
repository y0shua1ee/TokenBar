#if os(macOS)
import TokenBarCore
import Foundation
import Testing
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
}
#endif
