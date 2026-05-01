import Foundation

// MARK: - Krill Credits Response

public struct KrillCreditsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillCreditsData?

    public struct KrillCreditsData: Decodable, Sendable {
        public let balance_usd: String?
    }
}

// MARK: - Krill Subscription Response

public struct KrillSubscriptionResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillSubscriptionData?

    public struct KrillSubscriptionData: Decodable, Sendable {
        public let subscriptions: [KrillSubscription]?
        public let credit_balance_usd: String?
        public let request_count_quota: KrillRequestCountQuota?

        public struct KrillSubscription: Decodable, Sendable {
            public let subscription_id: Int
            public let plan: KrillPlan?
            public let quota: KrillQuota?
        }

        public struct KrillPlan: Decodable, Sendable {
            public let name: String?
            public let daily_quota_usd: String?
            public let rate_limit_5h: Int?
            public let rate_limit_weekly: Int?
            public let rate_limit_monthly: Int?
        }

        public struct KrillQuota: Decodable, Sendable {
            public let daily_limit_usd: String?
            public let used_usd: String?
            public let remaining_usd: String?
            public let limit_credits: Int?
            public let used_credits: Int?
            public let remaining_credits: Int?
        }

        public struct KrillRequestCountQuota: Decodable, Sendable {
            public let limit_5h: Int?
            public let used_5h: Int?
            public let limit_weekly: Int?
            public let used_weekly: Int?
            public let limit_monthly: Int?
            public let used_monthly: Int?
        }
    }
}

// MARK: - Krill Stats Response

public struct KrillStatsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillStatsData?

    public struct KrillStatsData: Decodable, Sendable {
        public let total_requests: Int?
        public let total_tokens: Int?
        public let total_cost_usd: String?
        public let channel_cache_rates: [KrillChannelCacheRate]?

        public struct KrillChannelCacheRate: Decodable, Sendable {
            public let channel_name: String?
            public let cache_rate: Double?
        }
    }
}

// MARK: - Krill Models Response

public struct KrillModelsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: [String]?
}
