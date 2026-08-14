import Foundation

public struct OpenRouterActivityResponse: Decodable, Equatable, Sendable {
    public let data: [OpenRouterActivityItem]
}

public struct OpenRouterActivityItem: Decodable, Equatable, Sendable {
    public let byokUsageInference: Double?
    public let completionTokens: Int?
    public let date: String
    public let endpointID: String?
    public let model: String?
    public let modelPermaslug: String?
    public let promptTokens: Int?
    public let providerName: String?
    public let reasoningTokens: Int?
    public let requests: Int?
    public let usage: Double?

    private enum CodingKeys: String, CodingKey {
        case byokUsageInference = "byok_usage_inference"
        case completionTokens = "completion_tokens"
        case date
        case endpointID = "endpoint_id"
        case model
        case modelPermaslug = "model_permaslug"
        case promptTokens = "prompt_tokens"
        case providerName = "provider_name"
        case reasoningTokens = "reasoning_tokens"
        case requests
        case usage
    }

    public init(
        byokUsageInference: Double?,
        completionTokens: Int?,
        date: String,
        endpointID: String?,
        model: String?,
        modelPermaslug: String?,
        promptTokens: Int?,
        providerName: String?,
        reasoningTokens: Int?,
        requests: Int?,
        usage: Double?)
    {
        self.byokUsageInference = byokUsageInference
        self.completionTokens = completionTokens
        self.date = date
        self.endpointID = endpointID
        self.model = model
        self.modelPermaslug = modelPermaslug
        self.promptTokens = promptTokens
        self.providerName = providerName
        self.reasoningTokens = reasoningTokens
        self.requests = requests
        self.usage = usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.byokUsageInference = Self.decodeFlexibleDouble(container, forKey: .byokUsageInference)
        self.completionTokens = Self.decodeFlexibleInt(container, forKey: .completionTokens)
        self.date = try container.decode(String.self, forKey: .date)
        self.endpointID = try container.decodeIfPresent(String.self, forKey: .endpointID)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.modelPermaslug = try container.decodeIfPresent(String.self, forKey: .modelPermaslug)
        self.promptTokens = Self.decodeFlexibleInt(container, forKey: .promptTokens)
        self.providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        self.reasoningTokens = Self.decodeFlexibleInt(container, forKey: .reasoningTokens)
        self.requests = Self.decodeFlexibleInt(container, forKey: .requests)
        self.usage = Self.decodeFlexibleDouble(container, forKey: .usage)
    }

    var inputTokensValue: Int? {
        self.promptTokens.map { max(0, $0) }
    }

    /// OpenRouter documents reasoning tokens as a subset of completion tokens. Keep them
    /// independently observable, but never add them to completion or total token counts.
    var outputTokensValue: Int? {
        self.completionTokens.map { max(0, $0) }
    }

    var reasoningTokensValue: Int? {
        self.reasoningTokens.map { max(0, $0) }
    }

    var totalTokensValue: Int? {
        guard self.promptTokens != nil || self.completionTokens != nil else { return nil }
        return (self.inputTokensValue ?? 0) + (self.outputTokensValue ?? 0)
    }

    var requestCountValue: Int? {
        self.requests.map { max(0, $0) }
    }

    var costUSDValue: Double? {
        guard self.usage != nil || self.byokUsageInference != nil else { return nil }
        return max(0, self.usage ?? 0) + max(0, self.byokUsageInference ?? 0)
    }

    var displayModelName: String? {
        for raw in [self.model, self.modelPermaslug, self.endpointID] {
            guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }
            return value
        }
        return nil
    }

    private static func decodeFlexibleInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys) -> Int?
    {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return Int(exactly: value.rounded(.towardZero))
        }
        guard let raw = try? container.decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return nil }
        if let value = Int(raw) { return value }
        guard let value = Double(raw), value.isFinite else { return nil }
        return Int(exactly: value.rounded(.towardZero))
    }

    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys) -> Double?
    {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        guard let raw = try? container.decodeIfPresent(String.self, forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = Double(raw),
            value.isFinite
        else { return nil }
        return value
    }
}

public struct OpenRouterActivityUsageReport: Equatable, Sendable {
    public let daily: [CostUsageDailyReport.Entry]
    /// Activity's request metric is retained separately because older shared cost snapshots
    /// did not carry per-day request counts through their summary conversion.
    public let requestsByDate: [String: Int]
    /// Reasoning is already included in completion tokens. These maps preserve the independent
    /// metric for future shared-model/UI projection without double-counting total tokens.
    public let reasoningTokensByDate: [String: Int]
    public let reasoningTokensByModelByDate: [String: [String: Int]]
    public let historyDays: Int
    public let updatedAt: Date

    public init(
        daily: [CostUsageDailyReport.Entry],
        requestsByDate: [String: Int],
        reasoningTokensByDate: [String: Int],
        reasoningTokensByModelByDate: [String: [String: Int]],
        historyDays: Int,
        updatedAt: Date)
    {
        self.daily = daily
        self.requestsByDate = requestsByDate
        self.reasoningTokensByDate = reasoningTokensByDate
        self.reasoningTokensByModelByDate = reasoningTokensByModelByDate
        self.historyDays = min(30, max(1, historyDays))
        self.updatedAt = updatedAt
    }

    public var totalRequests: Int? {
        Self.sum(self.requestsByDate.values)
    }

    public var totalReasoningTokens: Int? {
        Self.sum(self.reasoningTokensByDate.values)
    }

    public var historyLabel: String {
        "Last \(self.historyDays) completed UTC \(self.historyDays == 1 ? "day" : "days")"
    }

    public func toTokenSnapshot(managementKey: String, now: Date? = nil) -> CostUsageTokenSnapshot {
        let report = CostUsageDailyReport(data: self.daily, summary: Self.summary(from: self.daily))
        let base = CostUsageFetcher.tokenSnapshot(
            from: report,
            now: now ?? self.updatedAt,
            historyDays: self.historyDays,
            useCurrentLocalDayForSession: false,
            calendar: Self.utcCalendar,
            credentialScopeFingerprint: OpenRouterActivityUsageFetcher.credentialFingerprint(managementKey),
            historyLabel: self.historyLabel,
            updatedAt: self.updatedAt)
        let latestRequests = Self.latestEntry(in: self.daily)?.requestCount
        return CostUsageTokenSnapshot(
            sessionTokens: base.sessionTokens,
            sessionCostUSD: base.sessionCostUSD,
            sessionRequests: latestRequests,
            last30DaysTokens: base.last30DaysTokens,
            last30DaysCostUSD: base.last30DaysCostUSD,
            last30DaysRequests: self.totalRequests,
            currencyCode: base.currencyCode,
            historyDays: base.historyDays,
            historyCoverageIsEstablished: base.historyCoverageIsEstablished,
            historyLabel: base.historyLabel,
            meteredCostUSD: base.meteredCostUSD,
            credentialScopeFingerprint: base.credentialScopeFingerprint,
            daily: base.daily,
            projects: base.projects,
            sessions: base.sessions,
            updatedAt: base.updatedAt)
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        var rows: [ProviderDetailSection.Row] = [
            .makeRow(label: "Period", value: self.historyLabel),
        ]
        if let latest = Self.latestEntry(in: self.daily) {
            rows.append(.makeRow(label: "Latest completed UTC day", value: latest.date))
        }
        if let totalCost = Self.summary(from: self.daily)?.totalCostUSD {
            rows.append(.makeRow(label: "Cost", value: UsageFormatter.usdString(totalCost)))
        }
        if let totalRequests = self.totalRequests {
            rows.append(.makeRow(label: "Requests", value: UsageFormatter.tokenCountString(totalRequests)))
        }
        if let totalTokens = Self.summary(from: self.daily)?.totalTokens {
            rows.append(.makeRow(label: "Tokens", value: UsageFormatter.tokenCountString(totalTokens)))
        }
        if let reasoningTokens = self.totalReasoningTokens {
            rows.append(.makeRow(
                label: "Reasoning tokens",
                value: UsageFormatter.tokenCountString(reasoningTokens)))
        }
        let models = Set(self.daily.flatMap { $0.modelsUsed ?? [] })
        if !models.isEmpty {
            rows.append(.makeRow(label: "Models", value: String(models.count)))
        }

        return UsageSnapshot(
            primary: nil,
            secondary: nil,
            details: [.makeSection(title: "Account activity", rows: rows)],
            updatedAt: self.updatedAt,
            dataConfidence: .exact)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return calendar
    }

    private static func latestEntry(in entries: [CostUsageDailyReport.Entry]) -> CostUsageDailyReport.Entry? {
        entries.max { lhs, rhs in lhs.date < rhs.date }
    }

    private static func summary(from entries: [CostUsageDailyReport.Entry]) -> CostUsageDailyReport.Summary? {
        guard !entries.isEmpty else { return nil }
        return CostUsageDailyReport.Summary(
            totalInputTokens: self.sum(entries.compactMap(\.inputTokens)),
            totalOutputTokens: self.sum(entries.compactMap(\.outputTokens)),
            totalReasoningTokens: self.sum(entries.compactMap(\.reasoningTokens)),
            totalTokens: self.sum(entries.compactMap(\.totalTokens)),
            totalCostUSD: self.sum(entries.compactMap(\.costUSD)))
    }

    private static func sum(_ values: some Sequence<Int>) -> Int? {
        var iterator = values.makeIterator()
        guard let first = iterator.next() else { return nil }
        var total = first
        while let value = iterator.next() {
            total += value
        }
        return total
    }

    private static func sum(_ values: some Sequence<Double>) -> Double? {
        var iterator = values.makeIterator()
        guard let first = iterator.next() else { return nil }
        var total = first
        while let value = iterator.next() {
            total += value
        }
        return total
    }
}
