import Foundation
import TokenBarCore

struct DeepSeekProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .deepseek
    let supportsLoginFlow: Bool = true

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_: SettingsStore) {}

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if DeepSeekSettingsReader.apiKey(environment: context.environment) != nil {
            return true
        }
        return !context.settings.tokenAccounts(for: .deepseek).isEmpty
    }

    @MainActor
    func settingsFields(context _: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        []
    }

    @MainActor
    func loginMenuAction(context _: ProviderMenuLoginContext)
        -> (label: String, action: MenuDescriptor.MenuAction)?
    {
        ("Login to DeepSeek Dashboard...", .switchAccount(.deepseek))
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
