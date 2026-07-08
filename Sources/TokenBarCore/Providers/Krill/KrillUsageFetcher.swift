#if os(macOS)
import Foundation

/// Fetches Krill usage data using Krill's same-origin API with JWT auth.
/// Falls back to WebView login if JWT is missing or expired.
public enum KrillUsageFetcher: Sendable {
    public static func fetchUsage() async throws -> UsageSnapshot {
        // 1. Get JWT
        var jwt: String
        if let stored = await KrillJWTManager.shared.getStoredJWT() {
            jwt = stored
        } else {
            // No stored JWT — don't auto-pop the login window on fetch.
            // The user triggers login explicitly from the menu "Login" button.
            return self.buildEmptySnapshot()
        }

        // 2. Fetch the core account data first, then treat dashboard enrichment as best-effort.
        var firstError: (any Error)?
        let credits: KrillCreditsResponse?
        do {
            credits = try await KrillAPIClient.fetchCredits(jwt: jwt)
        } catch {
            firstError = error
            credits = nil
        }

        let subscription: KrillSubscriptionResponse?
        do {
            subscription = try await KrillAPIClient.fetchSubscription(jwt: jwt)
        } catch {
            firstError = firstError ?? error
            subscription = nil
        }

        guard credits != nil || subscription != nil else {
            throw firstError ?? KrillAPIError.missingJWT
        }

        let stats = try? await KrillAPIClient.fetchStats(jwt: jwt)
        let models = try? await KrillAPIClient.fetchModels(jwt: jwt)
        let activeQuota = try? await KrillAPIClient.fetchActiveSubscriptionDailyQuota(jwt: jwt)

        // 3. Build snapshot
        return self.buildSnapshot(
            credits: credits,
            subscription: subscription,
            stats: stats,
            activeQuota: activeQuota,
            modelCount: models?.count)
    }

    // MARK: - Snapshot Building

    static func buildSnapshot(
        credits: KrillCreditsResponse?,
        subscription: KrillSubscriptionResponse?,
        stats: KrillStatsResponse?,
        activeQuota: KrillActiveSubscriptionDailyQuotaResponse?,
        modelCount: Int?) -> UsageSnapshot
    {
        var primary: RateWindow?
        var secondary: RateWindow?
        var loginMethodParts = ["Krill"]

        // Extract wallet balance
        let balanceUSD = credits?.data?.balance_usd
            ?? subscription?.data?.credit_balance_usd

        // Extract subscriptions
        if let subs = subscription?.data?.subscriptions {
            for sub in subs {
                guard let planName = sub.plan?.name else { continue }

                // ── Elite: show credits remaining ──
                if planName.contains("Elite"),
                   let limitCredits = sub.quota?.limit_credits,
                   let remainingCredits = sub.quota?.remaining_credits,
                   limitCredits > 0
                {
                    let usedCredits = limitCredits - remainingCredits
                    let usedPct = min(100.0, (Double(usedCredits) / Double(limitCredits)) * 100.0)
                    primary = RateWindow(
                        usedPercent: usedPct,
                        windowMinutes: nil,
                        resetsAt: nil,
                        resetDescription: "Elite \(remainingCredits)/\(limitCredits) credits remaining")

                    // API names this USD-equivalent subscription quota `daily_limit_usd`, but the
                    // dashboard presents it as Elite credits quota, not today's request spend.
                    if let usedUSD = sub.quota?.used_usd,
                       let usdVal = Double(usedUSD)
                    {
                        if let limitUSD = sub.quota?.daily_limit_usd,
                           let limitVal = Double(limitUSD)
                        {
                            loginMethodParts.append(
                                "Elite quota $\(String(format: "%.2f", usdVal))/$\(String(format: "%.2f", limitVal))")
                        } else {
                            loginMethodParts.append("Elite quota $\(String(format: "%.2f", usdVal))")
                        }
                    }
                }

                // ── 尊享月卡: monthly request count ──
                if planName.contains("尊享月卡"),
                   let monthlyLimit = subscription?.data?.request_count_quota?.limit_monthly,
                   let monthlyUsed = subscription?.data?.request_count_quota?.used_monthly,
                   monthlyLimit > 0
                {
                    let usedPct = min(100.0, (Double(monthlyUsed) / Double(monthlyLimit)) * 100.0)
                    secondary = RateWindow(
                        usedPercent: usedPct,
                        windowMinutes: nil,
                        resetsAt: nil,
                        resetDescription: "尊享月卡 \(monthlyUsed)/\(monthlyLimit) requests this month")
                }
            }
        }

        // Cache rate from stats
        if let channels = stats?.data?.channel_cache_rates {
            let bestChannel = channels.max(by: {
                ($0.cache_rate ?? 0) < ($1.cache_rate ?? 0)
            })
            if let rate = bestChannel?.cache_rate {
                loginMethodParts.append("Cache \(Int(rate * 100))%")
            }
        }

        // Model count
        if let modelCount {
            loginMethodParts.append("\(modelCount) models")
        }

        // Build balance line
        var balanceStr = "Wallet: --"
        if let usdStr = balanceUSD, let bal = Double(usdStr) {
            balanceStr = "Wallet: $\(String(format: "%.2f", bal))"
        }

        let identity = ProviderIdentitySnapshot(
            providerID: .krill,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "\(balanceStr)\n\(loginMethodParts.joined(separator: " · "))")

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            providerCost: self.activeQuotaProviderCost(from: activeQuota),
            openRouterUsage: nil,
            updatedAt: Date(),
            identity: identity)
    }

    static func activeQuotaProviderCost(
        from response: KrillActiveSubscriptionDailyQuotaResponse?,
        now: Date = Date()) -> ProviderCostSnapshot?
    {
        guard let subscriptions = response?.data?.subscriptions else { return nil }

        var used = 0.0
        var limit = 0.0
        var labels: [String] = []

        for subscription in subscriptions {
            guard let item = self.latestQuotaItem(subscription.items) else { continue }
            let directUsed = self.doubleValue(item.used_usd) ?? 0
            let directLimit = self.doubleValue(item.daily_limit_usd) ?? 0
            let forwardedUsed = self.doubleValue(item.forwarded_used_usd) ?? 0
            let forwardedLimit = self.doubleValue(item.forwarded_limit_usd) ?? 0
            let itemUsed = directUsed + forwardedUsed
            let itemLimit = directLimit + forwardedLimit
            guard itemUsed > 0 || itemLimit > 0 else { continue }

            used += itemUsed
            limit += itemLimit

            if let label = self.activeQuotaLabel(for: subscription), !labels.contains(label) {
                labels.append(label)
            }
        }

        guard limit > 0 else { return nil }
        let period = labels.count == 1 ? labels[0] : "Active subscriptions"
        return ProviderCostSnapshot(
            used: used,
            limit: limit,
            currencyCode: "USD",
            period: period,
            updatedAt: now)
    }

    private static func latestQuotaItem(
        _ items: [KrillActiveSubscriptionDailyQuotaResponse.KrillActiveSubscriptionDailyQuotaItem]?)
        -> KrillActiveSubscriptionDailyQuotaResponse.KrillActiveSubscriptionDailyQuotaItem?
    {
        items?.max { lhs, rhs in
            (lhs.date ?? "") < (rhs.date ?? "")
        }
    }

    private static func activeQuotaLabel(
        for subscription: KrillActiveSubscriptionDailyQuotaResponse.KrillActiveSubscriptionDailyQuota) -> String?
    {
        let name = subscription.plan_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = name.isEmpty ? "Subscription" : name
        if let id = subscription.subscription_id {
            return "\(base) #\(id)"
        }
        return name.isEmpty ? nil : base
    }

    private static func doubleValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Returns a minimal snapshot when user cancels login or JWT is unavailable.
    private static func buildEmptySnapshot() -> UsageSnapshot {
        let identity = ProviderIdentitySnapshot(
            providerID: .krill,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "Wallet: --\nKrill · Login required")

        return UsageSnapshot(
            primary: nil,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            openRouterUsage: nil,
            updatedAt: Date(),
            identity: identity)
    }
}
#endif
