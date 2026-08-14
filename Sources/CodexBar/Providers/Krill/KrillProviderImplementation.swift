import CodexBarCore
import Foundation

struct KrillProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .krill
    let supportsLoginFlow: Bool = true

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "web" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings[providerConfig: .krill, field: .apiKey]
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if KrillSettingsReader.jwt(environment: context.environment) != nil {
            return true
        }
        return !context.settings[providerConfig: .krill, field: .apiKey]
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        do {
            let jwt = try await KrillLoginRunner().run()
            context.controller.settings[providerConfig: .krill, field: .apiKey] = jwt
            return true
        } catch {
            return false
        }
    }
}
