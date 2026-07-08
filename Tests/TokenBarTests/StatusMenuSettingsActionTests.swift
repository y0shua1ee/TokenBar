import AppKit
import Testing
import TokenBarCore
@testable import TokenBar

private final class SettingsActionNotificationValueBox: @unchecked Sendable {
    private let lock = NSLock()
    private var rawValue: String?

    func set(_ value: String?) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.rawValue = value
    }

    var value: String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.rawValue
    }
}

@MainActor
@Suite(.serialized)
struct StatusMenuSettingsActionTests {
    @Test
    func `settings menu action posts open settings notification`() async throws {
        StatusItemController.menuCardRenderingEnabled = false
        StatusItemController.setMenuRefreshEnabledForTesting(false)
        let settings = SettingsStore()
        settings.refreshFrequency = .manual
        settings.mergeIcons = false
        let fetcher = UsageFetcher()
        let controller = StatusItemController(
            store: UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings),
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)

        let receivedTab = SettingsActionNotificationValueBox()
        let token = NotificationCenter.default.addObserver(
            forName: .tokenbarOpenSettings,
            object: nil,
            queue: nil)
        { notification in
            receivedTab.set(notification.userInfo?["tab"] as? String)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        controller.showSettingsGeneral()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(receivedTab.value == PreferencesTab.general.rawValue)
    }
}
