import AppKit
import Testing
@testable import TokenBar
@testable import TokenBarCore

extension StatusMenuTests {
    @Test
    func `overview tab renders overview rows for all active providers when three or fewer`() {
        self.disableMenuCardsForTesting()
        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .claude
        settings.mergedMenuLastSelectedWasOverview = true

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            let shouldEnable = provider == .codex || provider == .claude || provider == .cursor
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

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        let ids = self.representedIDs(in: menu)
        let overviewRows = ids.filter { $0.hasPrefix("overviewRow-") }
        #expect(overviewRows.count == 3)
        #expect(overviewRows.contains("overviewRow-codex"))
        #expect(overviewRows.contains("overviewRow-claude"))
        #expect(overviewRows.contains("overviewRow-cursor"))
        #expect(ids.contains("menuCard") == false)
    }

    @Test
    func `overview tab honors stored subset when three or fewer`() {
        self.disableMenuCardsForTesting()
        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .claude
        settings.mergedMenuLastSelectedWasOverview = true

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            let shouldEnable = provider == .codex || provider == .claude || provider == .cursor
            settings.setProviderEnabled(provider: provider, metadata: metadata, enabled: shouldEnable)
        }
        _ = settings.setMergedOverviewProviderSelection(
            provider: .claude,
            isSelected: false,
            activeProviders: [.codex, .claude, .cursor])

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings)
        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: self.makeStatusBarForTesting())

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        let ids = self.representedIDs(in: menu)
        let overviewRows = ids.filter { $0.hasPrefix("overviewRow-") }
        #expect(overviewRows.count == 2)
        #expect(overviewRows.contains("overviewRow-codex"))
        #expect(overviewRows.contains("overviewRow-cursor"))
        #expect(overviewRows.contains("overviewRow-claude") == false)
        #expect(ids.contains("menuCard") == false)
    }

    @Test
    func `overview tab with explicit empty selection is hidden and shows provider detail`() {
        self.disableMenuCardsForTesting()
        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .codex
        settings.mergedMenuLastSelectedWasOverview = true
        settings.mergedOverviewSelectedProviders = []

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            let shouldEnable = provider == .codex ||
                provider == .claude ||
                provider == .cursor ||
                provider == .opencode
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

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        let ids = self.representedIDs(in: menu)
        let switcherButtons = self.switcherButtons(in: menu)
        #expect(switcherButtons.count == store.enabledProvidersForDisplay().count)
        #expect(switcherButtons.contains(where: { $0.title == "Overview" }) == false)
        #expect(switcherButtons.contains(where: { $0.state == .on && $0.tag == 0 }))
        #expect(ids.contains("menuCard"))
        #expect(ids.contains(where: { $0.hasPrefix("overviewRow-") }) == false)
        #expect(ids.contains("overviewEmptyState") == false)
        #expect(menu.items.contains(where: { $0.title == "No providers selected for Overview." }) == false)
    }

    @Test
    func `overview rows keep menu item action in rendered mode`() throws {
        StatusItemController.menuCardRenderingEnabled = true
        StatusItemController.setMenuRefreshEnabledForTesting(false)
        defer { self.disableMenuCardsForTesting() }

        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .codex
        settings.mergedMenuLastSelectedWasOverview = true

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

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        let claudeRow = try #require(menu.items.first {
            ($0.representedObject as? String) == "overviewRow-claude"
        })
        #expect(claudeRow.action != nil)
        #expect(claudeRow.target is StatusItemController)
    }

    @Test
    func `selecting overview row switches to provider detail`() async throws {
        self.disableMenuCardsForTesting()
        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = true
        settings.selectedMenuProvider = .codex
        settings.mergedMenuLastSelectedWasOverview = true

        let registry = ProviderRegistry.shared
        for provider in UsageProvider.allCases {
            guard let metadata = registry.metadata[provider] else { continue }
            let shouldEnable = provider == .codex || provider == .cursor
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
        controller.menuRefreshEnabledOverrideForTesting = true

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)

        var rebuildCount = 0
        controller._test_openMenuRebuildObserver = { _ in
            rebuildCount += 1
        }
        defer { controller._test_openMenuRebuildObserver = nil }

        let cursorRow = try #require(menu.items.first {
            ($0.representedObject as? String) == "overviewRow-cursor"
        })
        let action = try #require(cursorRow.action)
        let target = try #require(cursorRow.target as? StatusItemController)
        _ = target.perform(action, with: cursorRow)

        for _ in 0..<100 where rebuildCount == 0 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }

        #expect(settings.mergedMenuLastSelectedWasOverview == false)
        #expect(settings.selectedMenuProvider == .cursor)
        #expect(rebuildCount == 1)

        let ids = self.representedIDs(in: menu)
        #expect(ids.contains("menuCard"))
        #expect(ids.contains(where: { $0.hasPrefix("overviewRow-") }) == false)
        #expect(self.switcherButtons(in: menu).first(where: { $0.state == .on })?.tag == 2)
    }
}
