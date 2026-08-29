import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

extension StatusMenuTests {
    @Test
    func `menu open refreshes an overdue snapshot even without a recorded provider error`() async {
        self.disableMenuCardsForTesting()
        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .fiveMinutes
        settings.mergeIcons = false
        settings.refreshAllProvidersOnMenuOpen = false
        self.enableOnlyCodexForStaleSnapshotTesting(settings)

        let store = self.makeCodexStore(settings: settings, dashboardAuthorized: false)
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(
                    usedPercent: 2,
                    windowMinutes: 300,
                    resetsAt: Date().addingTimeInterval(-60),
                    resetDescription: nil),
                secondary: nil,
                updatedAt: Date().addingTimeInterval(-(16 * 60))),
            provider: .codex)
        var providerRefreshCount = 0
        var refreshInteractions: [ProviderInteraction] = []
        store._test_providerRefreshOverride = { provider in
            guard provider == .codex else { return }
            providerRefreshCount += 1
            refreshInteractions.append(ProviderInteractionContext.current)
            store._setSnapshotForTesting(
                UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: 1,
                        windowMinutes: 300,
                        resetsAt: Date().addingTimeInterval(5 * 60 * 60),
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: Date()),
                provider: .codex)
        }
        defer { store._test_providerRefreshOverride = nil }

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: UsageFetcher().loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: self.makeStatusBarForTesting())
        defer { controller.releaseStatusItemsForTesting() }
        controller.menuRefreshEnabledOverrideForTesting = true
        StatusItemController.setMenuOpenRefreshDelayForTesting(.zero)
        defer { StatusItemController.resetMenuOpenRefreshDelayForTesting() }

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        defer { controller.menuDidClose(menu) }

        #expect(controller.deferredMenuInteractionRefreshPending)
        for _ in 0..<80 where providerRefreshCount == 0 {
            await Task.yield()
        }

        #expect(providerRefreshCount == 1)
        #expect(refreshInteractions == [.background])
        #expect(!store.isUsageSnapshotOverdue(for: .codex))
    }

    private func enableOnlyCodexForStaleSnapshotTesting(_ settings: SettingsStore) {
        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            settings.setProviderEnabled(
                provider: provider,
                metadata: metadata,
                enabled: provider == .codex)
        }
    }
}
