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

// MARK: - Krill Active Subscription Daily Quota Response

public struct KrillActiveSubscriptionDailyQuotaResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillActiveSubscriptionDailyQuotaData?

    public struct KrillActiveSubscriptionDailyQuotaData: Decodable, Sendable {
        public let subscriptions: [KrillActiveSubscriptionDailyQuota]?
    }

    public struct KrillActiveSubscriptionDailyQuota: Decodable, Sendable {
        public let subscription_id: Int?
        public let plan_name: String?
        public let items: [KrillActiveSubscriptionDailyQuotaItem]?
    }

    public struct KrillActiveSubscriptionDailyQuotaItem: Decodable, Sendable {
        public let date: String?
        public let daily_limit_usd: String?
        public let used_usd: String?
        public let forwarded_limit_usd: String?
        public let forwarded_used_usd: String?
    }
}

// MARK: - Krill Stats Response

public struct KrillStatsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillStatsData?

    public struct KrillStatsData: Decodable, Sendable {
        public let total_requests: Int?
        public let success_requests: Int?
        public let failed_requests: Int?
        public let input_tokens: Int?
        public let output_tokens: Int?
        public let cache_creation_input_tokens: Int?
        public let cache_read_input_tokens: Int?
        public let reasoning_tokens: Int?
        public let total_tokens: Int?
        public let total_cost_usd: String?
        public let range_start: String?
        public let range_end: String?
        public let bucket_seconds: Int?
        public let trend: [KrillTrendBucket]?
        public let channel_cache_rates: [KrillChannelCacheRate]?

        public struct KrillTrendBucket: Decodable, Sendable {
            public let bucket_start: String?
            public let request_count: Int?
            public let total_tokens: Int?
            public let total_cost_usd: String?
        }

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
