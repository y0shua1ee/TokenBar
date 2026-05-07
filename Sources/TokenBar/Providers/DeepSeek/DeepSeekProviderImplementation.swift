import Foundation
import TokenBarCore
import TokenBarMacroSupport

@ProviderImplementationRegistration
struct DeepSeekProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .deepseek

    #if os(macOS)
    let supportsLoginFlow: Bool = true
    #endif

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
        #if os(macOS)
        if DeepSeekPlatformTokenManager.shared.getStoredToken() != nil {
            return ("Reconnect DeepSeek Dashboard...", .switchAccount(.deepseek))
        }
        #endif
        return ("Login to DeepSeek Dashboard...", .switchAccount(.deepseek))
    }

    #if os(macOS)
    @MainActor
    func runLoginFlow(context _: ProviderLoginContext) async -> Bool {
        do {
            _ = try await DeepSeekPlatformTokenManager.shared.loginViaWebView()
            return true
        } catch {
            return false
        }
    }
    #endif
}
