import Foundation

public enum OpenRouterProviderDescriptor {
    public static let descriptor: ProviderDescriptor = Self.makeDescriptor()
    private static let credentials = ProviderCredentialAdapter(
        supportsAPIKeyOverride: true,
        requiresAPIKeyForAPISource: false,
        usesSecretKey: true,
        apiKeyDebugLabel: OpenRouterSettingsReader.envKey,
        environmentProjections: [
            .apiKey(OpenRouterSettingsReader.envKey),
            .secretKey(OpenRouterSettingsReader.managementKeyEnvironmentKey),
            .enterpriseHost(OpenRouterSettingsReader.apiURLEnvironmentKey),
        ],
        tokenResolver: { kind, environment, _ in
            guard kind == .primary,
                  let token = OpenRouterSettingsReader.apiToken(environment: environment)
            else { return nil }
            return ProviderTokenResolution(token: token, source: .environment)
        },
        tokenAccountSupport: TokenAccountSupport(
            title: "API keys",
            subtitle: "Store multiple OpenRouter API keys.",
            placeholder: "sk-or-v1-...",
            injection: .environment(key: OpenRouterSettingsReader.envKey),
            requiresManualCookieSource: false,
            cookieName: nil,
            environmentKeysToScrub: [OpenRouterSettingsReader.managementKeyEnvironmentKey]),
        authDetector: { environment, _ in
            OpenRouterSettingsReader.apiToken(environment: environment) != nil ||
                OpenRouterSettingsReader.managementKey(environment: environment) != nil
                ? ["api"]
                : []
        },
        configValidator: { config in
            guard let raw = config.sanitizedEnterpriseHost,
                  ProviderEndpointOverrideValidator.normalizedHTTPSURL(from: raw) == nil
            else { return [] }
            return [CodexBarConfigIssue(
                severity: .error,
                provider: .openrouter,
                field: "enterpriseHost",
                code: "invalid_enterprise_host",
                message: OpenRouterSettingsError.invalidEndpointOverride(
                    OpenRouterSettingsReader.apiURLEnvironmentKey).errorDescription ?? "Invalid OpenRouter API URL.")]
        },
        missingCredentialMessage: { _ in OpenRouterSettingsError.missingToken.errorDescription })

    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .openrouter,
            menuBarMetrics: ProviderMenuBarMetricCapabilities(supported: [.automatic, .primary]),
            credentials: self.credentials,
            config: ProviderConfigCapabilities(supportsEnterpriseHost: true),
            metadata: ProviderMetadata(
                id: .openrouter,
                displayName: "OpenRouter",
                sessionLabel: "Credits",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Credit balance from OpenRouter API",
                toggleTitle: "Show OpenRouter usage",
                cliName: "openrouter",
                defaultEnabled: false,
                widgetSelectable: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://openrouter.ai/settings/credits",
                statusPageURL: nil,
                statusLinkURL: "https://status.openrouter.ai"),
            branding: ProviderBranding(
                iconStyle: .init(provider: .openrouter),
                iconResourceName: "ProviderIcon-openrouter",
                color: ProviderColor(red: 100 / 255, green: 103 / 255, blue: 242 / 255),
                confettiPalette: [
                    ProviderColor(hex: 0x96A5B9),
                    ProviderColor(hex: 0x161616),
                    ProviderColor(hex: 0xFFFFFF),
                ],
                widgetColor: ProviderColor(red: 111 / 255, green: 66 / 255, blue: 193 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: true,
                noDataMessage: {
                    "No OpenRouter account activity was reported for this period."
                },
                menuHintLines: [.literal("Reported by OpenRouter Activity for the whole account.")],
                supportsTokenSnapshot: true,
                estimateDisclaimer: "Reported by OpenRouter Activity.",
                primaryValue: .latestDaily,
                latestDayLabelStyle: .completedUTCDay),
            presentation: ProviderUsagePresentation(
                menuCard: ProviderMenuCardPresentation(
                    showsCreditsSection: false,
                    supportsInlineTokenCostDashboard: true,
                    primaryDescriptionPlacement: .reset),
                planRow: ProviderPlanRowPresentation(label: "Balance", stripsBalancePrefix: true)),
            fetchPlan: self.fetchPlan(),
            cli: ProviderCLIConfig(
                name: "openrouter",
                aliases: ["or"],
                versionDetector: nil,
                supportsCostCommand: true))
    }

    private static func fetchPlan() -> ProviderFetchPlan {
        ProviderFetchPlan(
            sourceModes: [.auto, .api],
            pipeline: ProviderFetchPipeline(resolveStrategies: self.resolveStrategies))
    }

    static func resolveStrategies(context: ProviderFetchContext) async -> [any ProviderFetchStrategy] {
        // A token-account refresh owns one ordinary API key. Account-wide Activity must never
        // be copied into that account card, even if the provider also has a management key.
        if context.selectedTokenAccountID != nil || OpenRouterSettingsReader.apiToken(environment: context.env) != nil {
            return [self.scriptStrategy()]
        }
        return [OpenRouterActivityFetchStrategy()]
    }

    private static func scriptStrategy() -> ScriptFetchStrategy {
        ScriptFetchStrategy(
            id: "openrouter.js",
            provider: .openrouter,
            bundledPlugin: "openrouter",
            secretKey: OpenRouterSettingsReader.envKey,
            sourceLabel: "api",
            validateContext: { context in
                try OpenRouterSettingsReader.validateEndpointOverrides(environment: context.env)
            },
            resolveValues: { context in
                guard let token = self.credentials.resolveToken(environment: context.env)?.token else {
                    return nil
                }
                var settings = [
                    OpenRouterSettingsReader.apiURLEnvironmentKey:
                        OpenRouterSettingsReader.apiURL(environment: context.env).absoluteString,
                    OpenRouterSettingsReader.clientTitleEnvironmentKey:
                        OpenRouterSettingsReader.clientTitle(environment: context.env),
                ]
                if let referer = OpenRouterSettingsReader.httpReferer(environment: context.env) {
                    settings[OpenRouterSettingsReader.httpRefererEnvironmentKey] = referer
                }
                return ScriptFetchStrategy.Values(
                    settings: settings,
                    secrets: [OpenRouterSettingsReader.envKey: token])
            },
            isEnabled: { _ in true })
    }
}

struct OpenRouterActivityFetchStrategy: ProviderFetchStrategy {
    typealias ReportLoader = @Sendable (String, Int) async throws -> OpenRouterActivityUsageReport

    let id = "openrouter.activity"
    let kind: ProviderFetchKind = .apiToken
    private let reportLoader: ReportLoader

    init(reportLoader: @escaping ReportLoader = { managementKey, historyDays in
        try await OpenRouterActivityUsageFetcher.loadDailyReport(
            managementKey: managementKey,
            historyDays: historyDays)
    }) {
        self.reportLoader = reportLoader
    }

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.selectedTokenAccountID == nil &&
            OpenRouterSettingsReader.managementKey(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard context.selectedTokenAccountID == nil,
              let managementKey = OpenRouterSettingsReader.managementKey(environment: context.env)
        else {
            throw OpenRouterActivityUsageError.missingManagementKey
        }
        let report = try await self.reportLoader(managementKey, context.costUsageHistoryDays)
        return self.makeResult(usage: report.toUsageSnapshot(), sourceLabel: "management-api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

/// Errors related to OpenRouter settings
public enum OpenRouterSettingsError: LocalizedError, Sendable, Equatable {
    case missingToken
    case invalidEndpointOverride(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "OpenRouter credentials not configured. Add an API key for balance/quota " +
                "or a management key for account activity."
        case let .invalidEndpointOverride(key):
            "OpenRouter endpoint override \(key) must use HTTPS or a bare host."
        }
    }
}
