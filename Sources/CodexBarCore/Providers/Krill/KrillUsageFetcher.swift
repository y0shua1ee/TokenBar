#if os(macOS)
import Foundation

/// Fetches Krill usage data using internal API (api.krill-ai.com) with JWT auth.
/// Falls back to WebView login if JWT is missing or expired.
public enum KrillUsageFetcher: Sendable {

    public static func fetchUsage() async throws -> UsageSnapshot {
        // 1. Get JWT
        var jwt: String
        if let stored = await KrillJWTManager.shared.getStoredJWT() {
            jwt = stored
        } else {
            jwt = try await KrillJWTManager.shared.loginViaWebView()
        }

        // 2. Fetch data in parallel
        async let creditsTask = KrillAPIClient.fetchCredits(jwt: jwt)
        async let subscriptionTask = KrillAPIClient.fetchSubscription(jwt: jwt)
        async let statsTask = KrillAPIClient.fetchStats(jwt: jwt)
        async let modelsTask = KrillAPIClient.fetchModels(jwt: jwt)

        let (credits, subscription, stats, models) = try await (
            creditsTask, subscriptionTask, statsTask, modelsTask)

        // 3. Build snapshot
        return buildSnapshot(
            credits: credits,
            subscription: subscription,
            stats: stats,
            modelCount: models.count)
    }

    // MARK: - Snapshot Building

    private static func buildSnapshot(
        credits: KrillCreditsResponse,
        subscription: KrillSubscriptionResponse,
        stats: KrillStatsResponse,
        modelCount: Int) -> UsageSnapshot
    {
        // Primary: Elite daily quota usage
        var primary: RateWindow?
        var secondary: RateWindow?
        var loginMethod = "Krill"

        // Extract Elite subscription quota
        if let subs = subscription.data?.subscriptions {
            for sub in subs {
                guard let planName = sub.plan?.name else { continue }
                if planName.contains("Elite"),
                   let dailyLimit = sub.quota?.daily_limit_usd,
                   let usedUSD = sub.quota?.used_usd,
                   let limitVal = Double(dailyLimit),
                   let usedVal = Double(usedUSD),
                   limitVal > 0
                {
                    let usedPct = min(100.0, (usedVal / limitVal) * 100.0)
                    primary = RateWindow(
                        usedPercent: usedPct,
                        windowMinutes: 1440, // daily
                        resetsAt: nil,
                        resetDescription: "Resets daily")

                    loginMethod += " | Elite $\(String(format: "%.2f", usedVal))/$\(String(format: "%.2f", limitVal)) today"
                }

                // 尊享月卡 request counts (secondary)
                if planName.contains("尊享月卡"),
                   let monthlyLimit = subscription.data?.request_count_quota?.limit_monthly,
                   let monthlyUsed = subscription.data?.request_count_quota?.used_monthly,
                   monthlyLimit > 0
                {
                    let usedPct = min(100.0, (Double(monthlyUsed) / Double(monthlyLimit)) * 100.0)
                    secondary = RateWindow(
                        usedPercent: usedPct,
                        windowMinutes: nil,
                        resetsAt: nil,
                        resetDescription: "\(monthlyUsed)/\(monthlyLimit) requests this month")
                }
            }
        }

        // Balance
        var balanceStr = "Balance: --"
        if let balanceUSD = credits.data?.balance_usd ?? subscription.data?.credit_balance_usd,
           let bal = Double(balanceUSD)
        {
            balanceStr = "Balance: $\(String(format: "%.2f", bal))"
        }

        // Total cost from stats
        if let costStr = stats.data?.total_cost_usd,
           let cost = Double(costStr)
        {
            loginMethod += " | Total: $\(String(format: "%.2f", cost))"
        }

        // Cache rate
        if let channels = stats.data?.channel_cache_rates {
            let bestChannel = channels.max(by: {
                ($0.cache_rate ?? 0) < ($1.cache_rate ?? 0)
            })
            if let rate = bestChannel?.cache_rate {
                loginMethod += " | Cache: \(Int(rate * 100))%"
            }
        }

        // Model count
        loginMethod += " | \(modelCount) models"

        let identity = ProviderIdentitySnapshot(
            providerID: .krill,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "\(balanceStr)\n\(loginMethod)")

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            providerCost: nil,
            openRouterUsage: nil,
            updatedAt: Date(),
            identity: identity)
    }
}
#endif
