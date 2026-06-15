import Foundation

public enum KrillProviderDescriptor {
    public static let descriptor: ProviderDescriptor = Self.makeDescriptor()

    public static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .krill,
            metadata: ProviderMetadata(
                id: .krill,
                displayName: "Krill",
                sessionLabel: "Elite Credits",
                weeklyLabel: "尊享月卡 Requests",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Krill wallet balance, Elite credits, and 尊享月卡 request quota",
                toggleTitle: "Show Krill usage",
                cliName: "krill",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://www.krill-ai.com/app",
                statusPageURL: nil,
                statusLinkURL: nil),
            branding: ProviderBranding(
                iconStyle: .krill,
                iconResourceName: "ProviderIcon-krill",
                color: ProviderColor(red: 0.39, green: 0.40, blue: 0.95)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: true,
                noDataMessage: { "Krill cost history is unavailable until you log in." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .web],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    #if os(macOS)
                    [KrillFetchStrategy()]
                    #else
                    []
                    #endif
                })),
            cli: ProviderCLIConfig(
                name: "krill",
                aliases: [],
                versionDetector: nil))
    }
}

#if os(macOS)
struct KrillFetchStrategy: ProviderFetchStrategy {
    let id: String = "krill.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        // Available on macOS (WebView support)
        true
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
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
