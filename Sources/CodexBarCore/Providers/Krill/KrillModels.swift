import Foundation

public struct KrillCreditsResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: DataPayload?

    public struct DataPayload: Decodable, Equatable, Sendable {
        public let balanceUSD: Double?

        private enum CodingKeys: String, CodingKey {
            case balanceUSD = "balance_usd"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.balanceUSD = container.decodeFlexibleDoubleIfPresent(forKey: .balanceUSD)
        }
    }
}

public struct KrillSubscriptionResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: DataPayload?

    public struct DataPayload: Decodable, Equatable, Sendable {
        public let subscriptions: [Subscription]?
        public let creditBalanceUSD: Double?
        public let requestCountQuota: RequestCountQuota?

        private enum CodingKeys: String, CodingKey {
            case subscriptions
            case creditBalanceUSD = "credit_balance_usd"
            case requestCountQuota = "request_count_quota"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.subscriptions = try container.decodeIfPresent([Subscription].self, forKey: .subscriptions)
            self.creditBalanceUSD = container.decodeFlexibleDoubleIfPresent(forKey: .creditBalanceUSD)
            self.requestCountQuota = try container.decodeIfPresent(RequestCountQuota.self, forKey: .requestCountQuota)
        }

        public struct Subscription: Decodable, Equatable, Sendable {
            public let subscriptionID: Int?
            public let plan: Plan?
            public let quota: Quota?

            private enum CodingKeys: String, CodingKey {
                case subscriptionID = "subscription_id"
                case plan
                case quota
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.subscriptionID = container.decodeFlexibleIntIfPresent(forKey: .subscriptionID)
                self.plan = try container.decodeIfPresent(Plan.self, forKey: .plan)
                self.quota = try container.decodeIfPresent(Quota.self, forKey: .quota)
            }
        }

        public struct Plan: Decodable, Equatable, Sendable {
            public let name: String?
            public let dailyQuotaUSD: Double?
            public let rateLimit5h: Int?
            public let rateLimitWeekly: Int?
            public let rateLimitMonthly: Int?

            private enum CodingKeys: String, CodingKey {
                case name
                case dailyQuotaUSD = "daily_quota_usd"
                case rateLimit5h = "rate_limit_5h"
                case rateLimitWeekly = "rate_limit_weekly"
                case rateLimitMonthly = "rate_limit_monthly"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
                self.dailyQuotaUSD = container.decodeFlexibleDoubleIfPresent(forKey: .dailyQuotaUSD)
                self.rateLimit5h = container.decodeFlexibleIntIfPresent(forKey: .rateLimit5h)
                self.rateLimitWeekly = container.decodeFlexibleIntIfPresent(forKey: .rateLimitWeekly)
                self.rateLimitMonthly = container.decodeFlexibleIntIfPresent(forKey: .rateLimitMonthly)
            }
        }

        public struct Quota: Decodable, Equatable, Sendable {
            public let dailyLimitUSD: Double?
            public let usedUSD: Double?
            public let remainingUSD: Double?
            public let limitCredits: Int?
            public let usedCredits: Int?
            public let remainingCredits: Int?

            private enum CodingKeys: String, CodingKey {
                case dailyLimitUSD = "daily_limit_usd"
                case usedUSD = "used_usd"
                case remainingUSD = "remaining_usd"
                case limitCredits = "limit_credits"
                case usedCredits = "used_credits"
                case remainingCredits = "remaining_credits"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.dailyLimitUSD = container.decodeFlexibleDoubleIfPresent(forKey: .dailyLimitUSD)
                self.usedUSD = container.decodeFlexibleDoubleIfPresent(forKey: .usedUSD)
                self.remainingUSD = container.decodeFlexibleDoubleIfPresent(forKey: .remainingUSD)
                self.limitCredits = container.decodeFlexibleIntIfPresent(forKey: .limitCredits)
                self.usedCredits = container.decodeFlexibleIntIfPresent(forKey: .usedCredits)
                self.remainingCredits = container.decodeFlexibleIntIfPresent(forKey: .remainingCredits)
            }
        }

        public struct RequestCountQuota: Decodable, Equatable, Sendable {
            public let limit5h: Int?
            public let used5h: Int?
            public let limitWeekly: Int?
            public let usedWeekly: Int?
            public let limitMonthly: Int?
            public let usedMonthly: Int?

            private enum CodingKeys: String, CodingKey {
                case limit5h = "limit_5h"
                case used5h = "used_5h"
                case limitWeekly = "limit_weekly"
                case usedWeekly = "used_weekly"
                case limitMonthly = "limit_monthly"
                case usedMonthly = "used_monthly"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.limit5h = container.decodeFlexibleIntIfPresent(forKey: .limit5h)
                self.used5h = container.decodeFlexibleIntIfPresent(forKey: .used5h)
                self.limitWeekly = container.decodeFlexibleIntIfPresent(forKey: .limitWeekly)
                self.usedWeekly = container.decodeFlexibleIntIfPresent(forKey: .usedWeekly)
                self.limitMonthly = container.decodeFlexibleIntIfPresent(forKey: .limitMonthly)
                self.usedMonthly = container.decodeFlexibleIntIfPresent(forKey: .usedMonthly)
            }
        }
    }
}

public struct KrillActiveSubscriptionDailyQuotaResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: DataPayload?

    public struct DataPayload: Decodable, Equatable, Sendable {
        public let subscriptions: [Subscription]?
    }

    public struct Subscription: Decodable, Equatable, Sendable {
        public let subscriptionID: Int?
        public let planName: String?
        public let items: [Item]?

        private enum CodingKeys: String, CodingKey {
            case subscriptionID = "subscription_id"
            case planName = "plan_name"
            case items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.subscriptionID = container.decodeFlexibleIntIfPresent(forKey: .subscriptionID)
            self.planName = try container.decodeIfPresent(String.self, forKey: .planName)
            self.items = try container.decodeIfPresent([Item].self, forKey: .items)
        }
    }

    public struct Item: Decodable, Equatable, Sendable {
        public let date: String?
        public let dailyLimitUSD: Double?
        public let usedUSD: Double?
        public let forwardedLimitUSD: Double?
        public let forwardedUsedUSD: Double?

        private enum CodingKeys: String, CodingKey {
            case date
            case dailyLimitUSD = "daily_limit_usd"
            case usedUSD = "used_usd"
            case forwardedLimitUSD = "forwarded_limit_usd"
            case forwardedUsedUSD = "forwarded_used_usd"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try container.decodeIfPresent(String.self, forKey: .date)
            self.dailyLimitUSD = container.decodeFlexibleDoubleIfPresent(forKey: .dailyLimitUSD)
            self.usedUSD = container.decodeFlexibleDoubleIfPresent(forKey: .usedUSD)
            self.forwardedLimitUSD = container.decodeFlexibleDoubleIfPresent(forKey: .forwardedLimitUSD)
            self.forwardedUsedUSD = container.decodeFlexibleDoubleIfPresent(forKey: .forwardedUsedUSD)
        }
    }
}

public struct KrillStatsResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: DataPayload?

    public struct DataPayload: Decodable, Equatable, Sendable {
        public let totalRequests: Int?
        public let successRequests: Int?
        public let failedRequests: Int?
        public let inputTokens: Int?
        public let outputTokens: Int?
        public let cacheCreationInputTokens: Int?
        public let cacheReadInputTokens: Int?
        public let reasoningTokens: Int?
        public let totalTokens: Int?
        public let totalCostUSD: Double?
        public let rangeStart: String?
        public let rangeEnd: String?
        public let bucketSeconds: Int?
        public let trend: [TrendBucket]?
        public let channelCacheRates: [ChannelCacheRate]?

        private enum CodingKeys: String, CodingKey {
            case totalRequests = "total_requests"
            case successRequests = "success_requests"
            case failedRequests = "failed_requests"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case reasoningTokens = "reasoning_tokens"
            case totalTokens = "total_tokens"
            case totalCostUSD = "total_cost_usd"
            case rangeStart = "range_start"
            case rangeEnd = "range_end"
            case bucketSeconds = "bucket_seconds"
            case trend
            case channelCacheRates = "channel_cache_rates"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.totalRequests = container.decodeFlexibleIntIfPresent(forKey: .totalRequests)
            self.successRequests = container.decodeFlexibleIntIfPresent(forKey: .successRequests)
            self.failedRequests = container.decodeFlexibleIntIfPresent(forKey: .failedRequests)
            self.inputTokens = container.decodeFlexibleIntIfPresent(forKey: .inputTokens)
            self.outputTokens = container.decodeFlexibleIntIfPresent(forKey: .outputTokens)
            self.cacheCreationInputTokens = container.decodeFlexibleIntIfPresent(forKey: .cacheCreationInputTokens)
            self.cacheReadInputTokens = container.decodeFlexibleIntIfPresent(forKey: .cacheReadInputTokens)
            self.reasoningTokens = container.decodeFlexibleIntIfPresent(forKey: .reasoningTokens)
            self.totalTokens = container.decodeFlexibleIntIfPresent(forKey: .totalTokens)
            self.totalCostUSD = container.decodeFlexibleDoubleIfPresent(forKey: .totalCostUSD)
            self.rangeStart = try container.decodeIfPresent(String.self, forKey: .rangeStart)
            self.rangeEnd = try container.decodeIfPresent(String.self, forKey: .rangeEnd)
            self.bucketSeconds = container.decodeFlexibleIntIfPresent(forKey: .bucketSeconds)
            self.trend = try container.decodeIfPresent([TrendBucket].self, forKey: .trend)
            self.channelCacheRates = try container.decodeIfPresent([ChannelCacheRate].self, forKey: .channelCacheRates)
        }

        public struct TrendBucket: Decodable, Equatable, Sendable {
            public let bucketStart: String?
            public let requestCount: Int?
            public let totalTokens: Int?
            public let totalCostUSD: Double?

            private enum CodingKeys: String, CodingKey {
                case bucketStart = "bucket_start"
                case requestCount = "request_count"
                case totalTokens = "total_tokens"
                case totalCostUSD = "total_cost_usd"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.bucketStart = try container.decodeIfPresent(String.self, forKey: .bucketStart)
                self.requestCount = container.decodeFlexibleIntIfPresent(forKey: .requestCount)
                self.totalTokens = container.decodeFlexibleIntIfPresent(forKey: .totalTokens)
                self.totalCostUSD = container.decodeFlexibleDoubleIfPresent(forKey: .totalCostUSD)
            }
        }

        public struct ChannelCacheRate: Decodable, Equatable, Sendable {
            public let channelName: String?
            public let cacheRate: Double?

            private enum CodingKeys: String, CodingKey {
                case channelName = "channel_name"
                case cacheRate = "cache_rate"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.channelName = try container.decodeIfPresent(String.self, forKey: .channelName)
                self.cacheRate = container.decodeFlexibleDoubleIfPresent(forKey: .cacheRate)
            }
        }
    }
}

public struct KrillModelStatsResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: DataPayload?

    public struct DataPayload: Decodable, Equatable, Sendable {
        public let items: [Item]?
    }

    public struct Item: Decodable, Equatable, Sendable {
        public let model: String?
        public let requestCount: Int?
        public let totalTokens: Int?
        public let totalCostUSD: Double?

        private enum CodingKeys: String, CodingKey {
            case model
            case requestCount = "request_count"
            case totalTokens = "total_tokens"
            case totalCostUSD = "total_cost_usd"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.model = try container.decodeIfPresent(String.self, forKey: .model)
            self.requestCount = container.decodeFlexibleIntIfPresent(forKey: .requestCount)
            self.totalTokens = container.decodeFlexibleIntIfPresent(forKey: .totalTokens)
            self.totalCostUSD = container.decodeFlexibleDoubleIfPresent(forKey: .totalCostUSD)
        }
    }
}

public struct KrillModelsResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let data: [String]?
}

extension KeyedDecodingContainer {
    fileprivate func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? self.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? self.decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return Int(exactly: value.rounded(.towardZero))
        }
        guard let raw = try? self.decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return nil }
        if let value = Int(raw) { return value }
        guard let value = Double(raw), value.isFinite else { return nil }
        return Int(exactly: value.rounded(.towardZero))
    }

    fileprivate func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? self.decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return value
        }
        if let value = try? self.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        guard let raw = try? self.decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = Double(raw),
            value.isFinite
        else { return nil }
        return value
    }
}
