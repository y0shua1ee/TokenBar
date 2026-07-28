import Foundation
import TokenBarCore

struct DeepSeekProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .deepseek
    let supportsLoginFlow: Bool = true
    private let hasStoredDashboardToken: @MainActor @Sendable () -> Bool

    init(
        hasStoredDashboardToken: @escaping @MainActor @Sendable () -> Bool = {
            DeepSeekPlatformTokenManager.shared.hasStoredToken()
        })
    {
        self.hasStoredDashboardToken = hasStoredDashboardToken
    }

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { context in
            context.store.sourceLabel(for: context.provider)
        }
    }

    @MainActor
    func observeSettings(_: SettingsStore) {}

    @MainActor
    func settingsFields(context _: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        []
    }

    @MainActor
    func loginMenuAction(context _: ProviderMenuLoginContext)
        -> (label: String, action: MenuDescriptor.MenuAction)?
    {
        let label = self.hasStoredDashboardToken()
            ? "Reconnect DeepSeek Dashboard..."
            : "Login to DeepSeek Dashboard..."
        return (label, .switchAccount(.deepseek))
    }

    @MainActor
    func runLoginFlow(context _: ProviderLoginContext) async -> Bool {
        do {
            _ = try await DeepSeekPlatformTokenManager.shared.loginViaWebView()
            return true
        } catch {
            return false
        }
    }
}
