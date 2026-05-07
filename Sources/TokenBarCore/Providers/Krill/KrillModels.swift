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

// MARK: - Krill Request Logs Response

public struct KrillRequestLogsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: KrillRequestLogsData?

    public struct KrillRequestLogsData: Decodable, Sendable {
        public let items: [KrillRequestLog]?
        public let total: Int?
        public let page: Int?
        public let page_size: Int?
    }

    public struct KrillRequestLog: Decodable, Sendable {
        public let request_time: String?
        public let original_model: String?
        public let actual_model: String?
        public let input_tokens: Int?
        public let output_tokens: Int?
        public let cache_creation_input_tokens: Int?
        public let cache_read_input_tokens: Int?
        public let reasoning_tokens: Int?
        public let total_tokens: Int?
        public let cost_usd: Double?
        public let plan_cost_usd: Double?
        public let credit_cost_usd: Double?
        public let status: String?

        private enum CodingKeys: String, CodingKey {
            case request_time
            case original_model
            case actual_model
            case input_tokens
            case output_tokens
            case cache_creation_input_tokens
            case cache_read_input_tokens
            case reasoning_tokens
            case total_tokens
            case cost_usd
            case plan_cost_usd
            case credit_cost_usd
            case status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.request_time = try container.decodeIfPresent(String.self, forKey: .request_time)
            self.original_model = try container.decodeIfPresent(String.self, forKey: .original_model)
            self.actual_model = try container.decodeIfPresent(String.self, forKey: .actual_model)
            self.input_tokens = Self.decodeInt(container, key: .input_tokens)
            self.output_tokens = Self.decodeInt(container, key: .output_tokens)
            self.cache_creation_input_tokens = Self.decodeInt(container, key: .cache_creation_input_tokens)
            self.cache_read_input_tokens = Self.decodeInt(container, key: .cache_read_input_tokens)
            self.reasoning_tokens = Self.decodeInt(container, key: .reasoning_tokens)
            self.total_tokens = Self.decodeInt(container, key: .total_tokens)
            self.cost_usd = Self.decodeDouble(container, key: .cost_usd)
            self.plan_cost_usd = Self.decodeDouble(container, key: .plan_cost_usd)
            self.credit_cost_usd = Self.decodeDouble(container, key: .credit_cost_usd)
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
        }

        private static func decodeInt(
            _ container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys) -> Int?
        {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Int(value)
            }
            guard let raw = try? container.decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else { return nil }
            return Int(raw) ?? Double(raw).map { Int($0) }
        }

        private static func decodeDouble(
            _ container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys) -> Double?
        {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            guard let raw = try? container.decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !raw.isEmpty
            else { return nil }
            return Double(raw)
        }
    }
}

// MARK: - Krill Models Response

public struct KrillModelsResponse: Decodable, Sendable {
    public let success: Bool
    public let data: [String]?
}
