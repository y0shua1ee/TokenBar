import TokenBarCore
import SwiftUI

struct KrillProviderImplementation: ProviderImplementation {
    var id: UsageProvider { .krill }
    var supportsLoginFlow: Bool { true }

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        do {
            _ = try await KrillJWTManager.shared.loginViaWebView()
            return true
        } catch {
            return false
        }
    }
}
