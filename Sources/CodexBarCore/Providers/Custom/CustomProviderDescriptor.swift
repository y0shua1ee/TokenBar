import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum CustomProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .custom,
            metadata: ProviderMetadata(
                id: .custom,
                displayName: "Custom",
                sessionLabel: "Credits",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Credit balance from custom API provider",
                toggleTitle: "Show custom provider usage",
                cliName: "custom",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: nil,
                statusPageURL: nil,
                statusLinkURL: nil),
            branding: ProviderBranding(
                iconStyle: .custom,
                iconResourceName: "",
                color: ProviderColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Cost tracking for custom providers is not yet supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    [CustomAPIFetchStrategy()]
                })),
            cli: ProviderCLIConfig(
                name: "custom",
                aliases: [],
                versionDetector: nil))
    }
}

struct CustomAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "custom.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        resolveToken(context.env) != nil && baseURL(context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = resolveToken(context.env) else {
            throw CustomProviderError.missingToken
        }
        guard let baseURLStr = baseURL(context.env) else {
            throw CustomProviderError.missingBaseURL
        }
        let displayName = context.env["CODEXBAR_CUSTOM_NAME"] ?? "Custom"

        let usage = try await CustomUsageFetcher.fetchUsage(
            apiKey: apiKey,
            baseURL: baseURLStr,
            displayName: displayName)

        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private func resolveToken(_ env: [String: String]) -> String? {
        if let val = env["CODEXBAR_CUSTOM_API_KEY"], !val.isEmpty { return val }
        return nil
    }

    private func baseURL(_ env: [String: String]) -> String? {
        if let val = env["CODEXBAR_CUSTOM_BASE_URL"], !val.isEmpty { return val }
        return nil
    }
}

public enum CustomProviderError: LocalizedError, Sendable {
    case missingToken
    case missingBaseURL
    case networkError(String)
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "Custom provider API token not configured. Set CODEXBAR_CUSTOM_API_KEY."
        case .missingBaseURL:
            "Custom provider base URL not configured. Set CODEXBAR_CUSTOM_BASE_URL."
        case let .networkError(msg):
            "Custom provider network error: \(msg)"
        case let .apiError(msg):
            "Custom provider API error: \(msg)"
        }
    }
}
