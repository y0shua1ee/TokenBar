import AppKit
import Testing
import TokenBarCore
@testable import TokenBar

@MainActor
@Suite(.serialized)
struct MergedMenuRealignmentTests {
    private func makeStatusBarForTesting() -> NSStatusBar {
        .system
    }

    private func makeSettings() -> SettingsStore {
        let suite = "MergedMenuRealignmentTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let configStore = testConfigStore(suiteName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: configStore,
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.providerDetectionCompleted = true
        return settings
    }

    @Test
    func `open merged menu provider switch schedules status item realignment`() {
        let previousMenuCardRendering = StatusItemController.menuCardRenderingEnabled
        let previousMenuRefresh = StatusItemController.menuRefreshEnabled
        StatusItemController.menuCardRenderingEnabled = false
        StatusItemController.setMenuRefreshEnabledForTesting(false)
        defer {
            StatusItemController.menuCardRenderingEnabled = previousMenuCardRendering
            StatusItemController.setMenuRefreshEnabledForTesting(previousMenuRefresh)
        }

        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .codex
        settings.mergedMenuLastSelectedWasOverview = false

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            let shouldEnable = provider == .codex || provider == .claude
            settings.setProviderEnabled(provider: provider, metadata: metadata, enabled: shouldEnable)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: self.makeStatusBarForTesting())
        defer { controller.releaseStatusItemsForTesting() }

        let menu = controller.makeMenu()
        controller.mergedMenu = menu
        controller.openMenus[ObjectIdentifier(menu)] = menu
        controller.populateMenu(menu, provider: .codex)

        var realignedMenus: [ObjectIdentifier] = []
        controller._test_openMergedMenuRealignmentScheduleObserver = { menu in
            realignedMenus.append(ObjectIdentifier(menu))
        }
        defer { controller._test_openMergedMenuRealignmentScheduleObserver = nil }

        settings.selectedMenuProvider = .claude
        controller.populateMenu(menu, provider: .claude)

        #expect(realignedMenus == [ObjectIdentifier(menu)])
    }
}
