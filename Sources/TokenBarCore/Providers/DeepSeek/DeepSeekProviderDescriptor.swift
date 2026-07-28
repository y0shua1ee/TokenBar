import Foundation

public enum DeepSeekProviderDescriptor {
    public static let descriptor: ProviderDescriptor = Self.makeDescriptor()

    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .deepseek,
            metadata: ProviderMetadata(
                id: .deepseek,
                displayName: "DeepSeek",
                sessionLabel: "Balance",
                weeklyLabel: "Balance",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show DeepSeek usage",
                cliName: "deepseek",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: "https://platform.deepseek.com/usage",
                statusPageURL: nil,
                statusLinkURL: "https://status.deepseek.com"),
            branding: ProviderBranding(
                iconStyle: .deepseek,
                iconResourceName: "ProviderIcon-deepseek",
                color: ProviderColor(red: 0.32, green: 0.49, blue: 0.94)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: true,
                noDataMessage: {
                    "DeepSeek dashboard usage is unavailable until you log in to platform.deepseek.com."
                }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api, .web],
                pipeline: ProviderFetchPipeline(resolveStrategies: self.resolveStrategies)),
            cli: ProviderCLIConfig(
                name: "deepseek",
                aliases: ["deep-seek", "ds"],
                versionDetector: nil))
    }

    static func resolveStrategies(context: ProviderFetchContext) async -> [any ProviderFetchStrategy] {
        switch context.sourceMode {
        case .auto:
            [DeepSeekAPIFetchStrategy(), DeepSeekDashboardFetchStrategy()]
        case .api:
            [DeepSeekAPIFetchStrategy()]
        case .web:
            [DeepSeekDashboardFetchStrategy()]
        case .cli, .oauth:
            []
        }
    }
}

struct DeepSeekAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "deepseek.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.sourceMode == .api || Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw DeepSeekUsageError.missingCredentials
        }
        let usage = try await DeepSeekUsageFetcher.fetchUsage(
            apiKey: apiKey,
            includeOptionalUsage: context.includeOptionalUsage)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.deepseekToken(environment: environment)
    }
}

struct DeepSeekDashboardFetchStrategy: ProviderFetchStrategy {
    struct Dependencies: Sendable {
        let loadToken: @Sendable () -> String?
        let now: @Sendable () -> Date
        let fetchDashboard: @Sendable (String, Date) async throws -> DeepSeekDashboardUsageSnapshot

        static var live: Self {
            #if os(macOS)
            Self(
                loadToken: { DeepSeekPlatformTokenStore.loadNoUI() },
                now: Date.init,
                fetchDashboard: { token, now in
                    try await DeepSeekDashboardUsageFetcher.fetchCurrentMonth(
                        platformToken: token,
                        now: now)
                })
            #else
            Self(
                loadToken: { nil },
                now: Date.init,
                fetchDashboard: { _, _ in
                    throw DeepSeekDashboardUsageError.missingPlatformToken
                })
            #endif
        }
    }

    let id: String = "deepseek.dashboard"
    let kind: ProviderFetchKind = .webDashboard
    private let dependencies: Dependencies

    init(dependencies: Dependencies = .live) {
        self.dependencies = dependencies
    }

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        #if os(macOS)
        if context.sourceMode == .web { return true }
        if self.dependencies.loadToken() != nil { return true }
        return DeepSeekAPIFetchStrategy.resolveToken(environment: context.env) == nil
        #else
        return false
        #endif
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let token = self.dependencies.loadToken() else {
            throw DeepSeekDashboardUsageError.missingPlatformToken
        }
        let now = self.dependencies.now()
        let dashboard = try await self.dependencies.fetchDashboard(token, now)
        return self.makeResult(
            usage: dashboard.toUsageSnapshot(now: now),
            sourceLabel: "web")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
