import Foundation

public enum KrillProviderDescriptor {
    public static let descriptor: ProviderDescriptor = Self.makeDescriptor()
    private static let credentials = ProviderCredentialAdapter.apiKey(
        environmentKey: KrillSettingsReader.projectedJWTEnvironmentKey,
        resolve: KrillSettingsReader.jwt,
        missingCredentialMessage: { _ in KrillJWTError.missing.errorDescription })

    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .krill,
            credentials: self.credentials,
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
                widgetSelectable: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: KrillAPIClient.dashboardURL.absoluteString,
                statusPageURL: nil,
                statusLinkURL: nil),
            branding: ProviderBranding(
                iconStyle: .init(provider: .krill),
                iconResourceName: "ProviderIcon-krill",
                color: ProviderColor(red: 0.39, green: 0.40, blue: 0.95),
                confettiPalette: [
                    ProviderColor(hex: 0x6366F1),
                    ProviderColor(hex: 0x8B5CF6),
                    ProviderColor(hex: 0xFFFFFF),
                ]),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: true,
                noDataMessage: { "Krill cost history is unavailable until you log in." },
                supportsTokenSnapshot: true,
                estimateDisclaimer: "Reported by Krill usage API."),
            presentation: ProviderUsagePresentation(
                costPresenter: { _ in ProviderCostPresentation(menuCardStyle: .activeQuota) },
                menuCard: ProviderMenuCardPresentation(
                    supportsInlineTokenCostDashboard: true,
                    usesRawPrimaryResetDescription: true),
                menu: ProviderMenuDescriptorPresentation(
                    primaryDescriptionIsDetail: { _ in true },
                    secondaryDescriptionMode: .resetOverride)),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [KrillFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "krill",
                aliases: [],
                versionDetector: nil))
    }
}

struct KrillFetchStrategy: ProviderFetchStrategy {
    let id = "krill.api"
    let kind: ProviderFetchKind = .apiToken
    private let transport: any ProviderHTTPTransport

    init(transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) {
        self.transport = transport
    }

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        KrillSettingsReader.jwt(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let jwt = try KrillSettingsReader.validatedJWT(environment: context.env)
        let result = try await KrillUsageFetcher(transport: self.transport).fetchUsage(
            jwt: jwt,
            includeOptionalUsage: context.includeOptionalUsage)
        return self.makeResult(
            usage: result.usage,
            credits: result.credits,
            sourceLabel: "Krill web login")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
