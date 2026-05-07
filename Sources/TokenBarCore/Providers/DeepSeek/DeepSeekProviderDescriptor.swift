import Foundation
import TokenBarMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum DeepSeekProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .deepseek,
            metadata: ProviderMetadata(
                id: .deepseek,
                displayName: "DeepSeek",
                sessionLabel: "Recharge balance",
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
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [DeepSeekAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "deepseek",
                aliases: ["deep-seek", "ds"],
                versionDetector: nil))
    }
}

struct DeepSeekAPIFetchStrategy: ProviderFetchStrategy {
    private static let log = CodexBarLog.logger(LogCategories.deepSeekUsage)

    let id: String = "deepseek.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw DeepSeekUsageError.missingCredentials
        }
        let (usage, dashboard) = try await Self.fetchUsageAndDashboard(apiKey: apiKey)
        return self.makeResult(
            usage: usage.toUsageSnapshot(dashboard: dashboard),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.deepseekToken(environment: environment)
    }

    private enum FetchPart: Sendable {
        case usage(DeepSeekUsageSnapshot)
        case dashboard(DeepSeekDashboardUsageSnapshot?)
    }

    private static func fetchUsageAndDashboard(apiKey: String) async throws
        -> (DeepSeekUsageSnapshot, DeepSeekDashboardUsageSnapshot?)
    {
        var usage: DeepSeekUsageSnapshot?
        var dashboard: DeepSeekDashboardUsageSnapshot?

        try await withThrowingTaskGroup(of: FetchPart.self) { group in
            group.addTask {
                let usage = try await DeepSeekUsageFetcher.fetchUsage(apiKey: apiKey)
                return .usage(usage)
            }
            group.addTask {
                let dashboard = await Self.fetchDashboardUsageIfAvailable()
                return .dashboard(dashboard)
            }

            for try await part in group {
                switch part {
                case let .usage(value):
                    usage = value
                case let .dashboard(value):
                    dashboard = value
                }
            }
        }

        guard let usage else {
            throw DeepSeekDashboardUsageError.parseFailed("Missing DeepSeek balance response.")
        }
        return (usage, dashboard)
    }

    private static func fetchDashboardUsageIfAvailable() async -> DeepSeekDashboardUsageSnapshot? {
        #if os(macOS)
        guard let token = await MainActor.run(
            resultType: String?.self,
            body: { DeepSeekPlatformTokenManager.shared.getStoredToken() })
        else {
            return nil
        }

        do {
            return try await DeepSeekDashboardUsageFetcher.fetchCurrentMonth(platformToken: token)
        } catch {
            Self.log.debug("DeepSeek dashboard usage unavailable: \(error.localizedDescription)")
            return nil
        }
        #else
        return nil
        #endif
    }
}
