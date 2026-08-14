import Foundation

public struct KrillUsageFetchResult: Sendable {
    public let usage: UsageSnapshot
    public let credits: CreditsSnapshot?

    public init(usage: UsageSnapshot, credits: CreditsSnapshot?) {
        self.usage = usage
        self.credits = credits
    }
}

public struct KrillUsageFetcher: Sendable {
    private let client: KrillAPIClient

    public init(
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared,
        baseURL: URL = KrillAPIClient.baseURL)
    {
        self.client = KrillAPIClient(baseURL: baseURL, transport: transport)
    }

    public func fetchUsage(
        jwt: String,
        now: Date = Date(),
        includeOptionalUsage: Bool = true) async throws -> KrillUsageFetchResult
    {
        try KrillJWT.validated(jwt, now: now)

        var firstRequiredError: (any Error)?
        let credits: KrillCreditsResponse?
        do {
            credits = try await self.client.fetchCredits(jwt: jwt)
        } catch {
            try KrillCancellation.propagate(error)
            firstRequiredError = error
            credits = nil
        }

        try Task.checkCancellation()
        let subscription: KrillSubscriptionResponse?
        do {
            subscription = try await self.client.fetchSubscription(jwt: jwt)
        } catch {
            try KrillCancellation.propagate(error)
            firstRequiredError = firstRequiredError ?? error
            subscription = nil
        }

        guard credits != nil || subscription != nil else {
            throw firstRequiredError ?? KrillAPIError.invalidResponse("account")
        }

        let stats: KrillStatsResponse?
        if includeOptionalUsage {
            do {
                try Task.checkCancellation()
                stats = try await self.client.fetchStats(jwt: jwt)
            } catch {
                try KrillCancellation.propagate(error)
                stats = nil
            }
        } else {
            stats = nil
        }

        let models: [String]?
        if includeOptionalUsage {
            do {
                try Task.checkCancellation()
                models = try await self.client.fetchModels(jwt: jwt)
            } catch {
                try KrillCancellation.propagate(error)
                models = nil
            }
        } else {
            models = nil
        }

        let activeQuota: KrillActiveSubscriptionDailyQuotaResponse?
        if includeOptionalUsage {
            do {
                try Task.checkCancellation()
                activeQuota = try await self.client.fetchActiveSubscriptionDailyQuota(jwt: jwt)
            } catch {
                try KrillCancellation.propagate(error)
                activeQuota = nil
            }
        } else {
            activeQuota = nil
        }

        try Task.checkCancellation()
        let usage = Self.buildSnapshot(
            credits: credits,
            subscription: subscription,
            stats: stats,
            activeQuota: activeQuota,
            modelCount: models?.count,
            now: now)
        return KrillUsageFetchResult(
            usage: usage,
            credits: Self.creditsSnapshot(credits: credits, subscription: subscription, now: now))
    }

    static func buildSnapshot(
        credits: KrillCreditsResponse?,
        subscription: KrillSubscriptionResponse?,
        stats: KrillStatsResponse?,
        activeQuota: KrillActiveSubscriptionDailyQuotaResponse?,
        modelCount: Int?,
        now: Date = Date()) -> UsageSnapshot
    {
        var primary: RateWindow?
        var secondary: RateWindow?
        var detailRows: [ProviderDetailSection.Row] = []

        let balanceUSD = credits?.data?.balanceUSD ?? subscription?.data?.creditBalanceUSD
        if let balanceUSD {
            detailRows.append(.makeRow(label: "Wallet", value: "$\(Self.currency(balanceUSD))"))
        }
        if let subscriptions = subscription?.data?.subscriptions {
            for item in subscriptions {
                let planName = item.plan?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if planName.contains("Elite"),
                   let limit = item.quota?.limitCredits,
                   limit > 0,
                   let used = Self.usedCredits(in: item.quota, limit: limit)
                {
                    let remaining = max(0, limit - used)
                    primary = RateWindow(
                        usedPercent: Self.percentage(used: used, limit: limit),
                        windowMinutes: nil,
                        resetsAt: nil,
                        resetDescription: "Elite \(remaining)/\(limit) credits remaining")

                    if let quotaUsed = item.quota?.usedUSD {
                        let value = Self.currency(quotaUsed)
                        if let quotaLimit = item.quota?.dailyLimitUSD {
                            detailRows.append(.makeRow(
                                label: "Elite quota",
                                value: "$\(value) / $\(Self.currency(quotaLimit))"))
                        } else {
                            detailRows.append(.makeRow(label: "Elite quota", value: "$\(value)"))
                        }
                    }
                }

                if planName.contains("尊享月卡"),
                   let quota = subscription?.data?.requestCountQuota,
                   let limit = quota.limitMonthly,
                   let used = quota.usedMonthly,
                   limit > 0
                {
                    secondary = RateWindow(
                        usedPercent: Self.percentage(used: used, limit: limit),
                        windowMinutes: nil,
                        resetsAt: nil,
                        resetDescription: "尊享月卡 \(used)/\(limit) requests this month")
                }
            }
        }

        if let rate = stats?.data?.channelCacheRates?.compactMap(\.cacheRate).max(), rate.isFinite {
            detailRows.append(.makeRow(
                label: "Best cache rate",
                value: "\(Int((min(1, max(0, rate)) * 100).rounded()))%"))
        }
        if let modelCount {
            detailRows.append(.makeRow(label: "Available models", value: String(modelCount)))
        }

        let identity = ProviderIdentitySnapshot(
            providerID: UsageProvider.krill.instanceID,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "Web")

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            providerCost: Self.activeQuotaProviderCost(from: activeQuota, now: now),
            details: detailRows.isEmpty ? [] : [.makeSection(title: "Account", rows: detailRows)],
            updatedAt: now,
            identity: identity,
            dataConfidence: .exact)
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
            guard let item = subscription.items?.max(by: { ($0.date ?? "") < ($1.date ?? "") }) else {
                continue
            }
            let itemUsed = (item.usedUSD ?? 0) + (item.forwardedUsedUSD ?? 0)
            let itemLimit = (item.dailyLimitUSD ?? 0) + (item.forwardedLimitUSD ?? 0)
            guard itemUsed > 0 || itemLimit > 0 else { continue }
            used += itemUsed
            limit += itemLimit

            let name = subscription.planName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let base = name.isEmpty ? "Subscription" : name
            let label = subscription.subscriptionID.map { "\(base) #\($0)" } ?? (name.isEmpty ? nil : base)
            if let label, !labels.contains(label) {
                labels.append(label)
            }
        }

        guard limit > 0 else { return nil }
        return ProviderCostSnapshot(
            used: used,
            limit: limit,
            currencyCode: "USD",
            period: labels.count == 1 ? labels[0] : "Active subscriptions",
            updatedAt: now)
    }

    private static func creditsSnapshot(
        credits: KrillCreditsResponse?,
        subscription: KrillSubscriptionResponse?,
        now: Date) -> CreditsSnapshot?
    {
        guard let balance = credits?.data?.balanceUSD ?? subscription?.data?.creditBalanceUSD else { return nil }
        return CreditsSnapshot(remaining: balance, events: [], updatedAt: now)
    }

    private static func usedCredits(
        in quota: KrillSubscriptionResponse.DataPayload.Quota?,
        limit: Int) -> Int?
    {
        if let remaining = quota?.remainingCredits { return max(0, limit - remaining) }
        if let used = quota?.usedCredits { return max(0, used) }
        return nil
    }

    private static func percentage(used: Int, limit: Int) -> Double {
        min(100, max(0, Double(used) / Double(limit) * 100))
    }

    private static func currency(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
