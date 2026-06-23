import Foundation
import TokenBarCore

extension Notification.Name {
    static let tokenbarOpenSettings = Notification.Name("tokenbarOpenSettings")
    static let tokenbarDebugBlinkNow = Notification.Name("tokenbarDebugBlinkNow")
    #if DEBUG
    static let tokenbarDebugSimulateMemoryPressure =
        Notification.Name("com.y0shua1ee.tokenbar.debug.simulateMemoryPressure")
    #endif
    static let tokenbarWeeklyLimitReset = Notification.Name("tokenbarWeeklyLimitReset")
    static let tokenbarProviderConfigDidChange = Notification.Name("tokenbarProviderConfigDidChange")
    static let tokenbarQuotaWarningDidPost = Notification.Name("tokenbarQuotaWarningDidPost")
}

@MainActor
final class WeeklyLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class QuotaWarningPostedEvent: NSObject {
    let provider: UsageProvider
    let window: QuotaWarningWindow
    let threshold: Int
    let postedAt: Date

    init(provider: UsageProvider, window: QuotaWarningWindow, threshold: Int, postedAt: Date) {
        self.provider = provider
        self.window = window
        self.threshold = threshold
        self.postedAt = postedAt
    }
}
