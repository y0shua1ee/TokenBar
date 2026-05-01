#if os(macOS)
import TokenBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum KrillProviderDescriptor {
    public static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .krill,
            metadata: ProviderMetadata(
                id: .krill,
                displayName: "Krill",
                sessionLabel: "Balance",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Krill wallet balance and subscription quota",
                toggleTitle: "Show Krill usage",
                cliName: "krill",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://www.krill-ai.com/app",
                statusPageURL: nil,
                statusLinkURL: nil),
            branding: ProviderBranding(
                iconStyle: .custom,
                iconResourceName: "",
                color: ProviderColor(red: 0.39, green: 0.40, blue: 0.95)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Per-model cost tracking for Krill is not yet supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .web],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    [KrillFetchStrategy()]
                })),
            cli: ProviderCLIConfig(
                name: "krill",
                aliases: [],
                versionDetector: nil))
    }
}

struct KrillFetchStrategy: ProviderFetchStrategy {
    let id: String = "krill.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        // Available on macOS (WebView support)
        true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let usage = try await KrillUsageFetcher.fetchUsage()

        return ProviderFetchResult(
            usage: usage,
            credits: nil,
            dashboard: nil,
            sourceLabel: "krill-api",
            strategyID: self.id,
            strategyKind: self.kind)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
#endif
