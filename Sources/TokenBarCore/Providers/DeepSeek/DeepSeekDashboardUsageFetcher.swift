import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DeepSeekDashboardUsageError: LocalizedError, Sendable {
    case missingPlatformToken
    case invalidURL
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingPlatformToken:
            "Missing DeepSeek dashboard login."
        case .invalidURL:
            "Invalid DeepSeek dashboard API URL."
        case let .networkError(message):
            "DeepSeek dashboard network error: \(message)"
        case let .apiError(message):
            "DeepSeek dashboard API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse DeepSeek dashboard usage: \(message)"
        }
    }
}

public struct DeepSeekDashboardUsageSnapshot: Sendable, Equatable {
    public let currencyCode: String
    public let monthlyCost: Double
    public let requestCount: Int
    public let totalTokens: Int
    public let models: [String]
    public let daily: [CostUsageDailyReport.Entry]
    public let updatedAt: Date

    public init(
        currencyCode: String,
        monthlyCost: Double,
        requestCount: Int,
        totalTokens: Int,
        models: [String],
        daily: [CostUsageDailyReport.Entry],
        updatedAt: Date)
    {
        self.currencyCode = currencyCode
        self.monthlyCost = monthlyCost
        self.requestCount = requestCount
        self.totalTokens = totalTokens
        self.models = models
        self.daily = daily
        self.updatedAt = updatedAt
    }

    public func toTokenSnapshot(now: Date = Date()) -> CostUsageTokenSnapshot {
        let report = CostUsageDailyReport(
            data: self.daily,
            summary: CostUsageDailyReport.Summary(
                totalInputTokens: nil,
                totalOutputTokens: nil,
                cacheReadTokens: nil,
                cacheCreationTokens: nil,
                totalTokens: self.totalTokens > 0 ? self.totalTokens : nil,
                totalCostUSD: self.monthlyCost > 0 ? self.monthlyCost : nil))
        let snapshot = CostUsageFetcher.tokenSnapshot(from: report, now: now)
        return CostUsageTokenSnapshot(
            sessionTokens: snapshot.sessionTokens,
            sessionCostUSD: snapshot.sessionCostUSD,
            last30DaysTokens: snapshot.last30DaysTokens,
            last30DaysCostUSD: snapshot.last30DaysCostUSD,
            last30DaysRequests: self.requestCount > 0 ? self.requestCount : nil,
            currencyCode: self.currencyCode,
            daily: snapshot.daily,
            updatedAt: snapshot.updatedAt)
    }

    public func toProviderCost() -> ProviderCostSnapshot? {
        guard self.monthlyCost > 0 else { return nil }
        return ProviderCostSnapshot(
            used: self.monthlyCost,
            limit: self.monthlyCost,
            currencyCode: self.currencyCode,
            period: "This month",
            updatedAt: self.updatedAt)
    }
}

public enum DeepSeekDashboardUsageFetcher: Sendable {
    private static let baseURL = "https://platform.deepseek.com"
    private static let timeoutSeconds: TimeInterval = 15

    public static func fetchCurrentMonth(
        platformToken: String,
        now: Date = Date()) async throws -> DeepSeekDashboardUsageSnapshot
    {
        guard !platformToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekDashboardUsageError.missingPlatformToken
        }

        let components = Calendar.current.dateComponents([.year, .month], from: now)
        let year = components.year ?? 1970
        let month = components.month ?? 1

        let costData = try await self.fetchEndpoint(
            path: "/api/v0/usage/cost",
            year: year,
            month: month,
            platformToken: platformToken)
        let amountData = try await self.fetchEndpoint(
            path: "/api/v0/usage/amount",
            year: year,
            month: month,
            platformToken: platformToken)

        return try self.parseSnapshot(costData: costData, amountData: amountData, now: now)
    }

    static func _parseSnapshotForTesting(
        costData: Data,
        amountData: Data,
        now: Date = Date()) throws -> DeepSeekDashboardUsageSnapshot
    {
        try self.parseSnapshot(costData: costData, amountData: amountData, now: now)
    }

    private static func fetchEndpoint(
        path: String,
        year: Int,
        month: Int,
        platformToken: String) async throws -> Data
    {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw DeepSeekDashboardUsageError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "month", value: "\(month)"),
            URLQueryItem(name: "year", value: "\(year)"),
        ]
        guard let url = components.url else {
            throw DeepSeekDashboardUsageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(platformToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://platform.deepseek.com/usage", forHTTPHeaderField: "Referer")
        request.timeoutInterval = Self.timeoutSeconds

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekDashboardUsageError.networkError("Invalid response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DeepSeekDashboardUsageError.apiError("HTTP \(httpResponse.statusCode)")
        }
        try self.validateBusinessEnvelope(data)
        return data
    }

    private static func validateBusinessEnvelope(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let code = object["code"] as? Int, code != 0 else { return }
        let message = (object["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message, !message.isEmpty {
            throw DeepSeekDashboardUsageError.apiError("\(message) (code \(code))")
        }
        throw DeepSeekDashboardUsageError.apiError("code \(code)")
    }

    private static func parseSnapshot(
        costData: Data,
        amountData: Data,
        now: Date) throws -> DeepSeekDashboardUsageSnapshot
    {
        let costPayload: DeepSeekDashboardUsageData
        let amountPayload: DeepSeekDashboardUsageData
        do {
            costPayload = try JSONDecoder().decode(DeepSeekDashboardUsageEnvelope.self, from: costData).data
            amountPayload = try JSONDecoder().decode(DeepSeekDashboardUsageEnvelope.self, from: amountData).data
        } catch {
            throw DeepSeekDashboardUsageError.parseFailed(error.localizedDescription)
        }

        let daily = self.dailyEntries(cost: costPayload.days, amount: amountPayload.days)
        let totalCost = self.totalCost(from: costPayload, daily: daily)
        let amountTotals = self.amountTotals(from: amountPayload, daily: daily)
        let models = self.models(costPayload: costPayload, amountPayload: amountPayload, daily: daily)
        let currency = self.currencyCode(from: costPayload)

        return DeepSeekDashboardUsageSnapshot(
            currencyCode: currency,
            monthlyCost: totalCost,
            requestCount: amountTotals.requests,
            totalTokens: amountTotals.tokens,
            models: models,
            daily: daily,
            updatedAt: now)
    }

    private static func dailyEntries(
        cost costDays: [DeepSeekDashboardDayUsage],
        amount amountDays: [DeepSeekDashboardDayUsage]) -> [CostUsageDailyReport.Entry]
    {
        let costByDate = self.aggregatesByDateModel(days: costDays, kind: .cost)
        let amountByDate = self.aggregatesByDateModel(days: amountDays, kind: .amount)
        let dateKeys = Set(costByDate.keys).union(amountByDate.keys).sorted()

        return dateKeys.map { date in
            let costModels = costByDate[date] ?? [:]
            let amountModels = amountByDate[date] ?? [:]
            let modelNames = Set(costModels.keys).union(amountModels.keys).sorted()

            var dayTotal = DeepSeekDashboardUsageAggregate()
            var breakdowns: [CostUsageDailyReport.ModelBreakdown] = []

            for modelName in modelNames {
                var modelTotal = DeepSeekDashboardUsageAggregate()
                if let amount = amountModels[modelName] { modelTotal.merge(amount) }
                if let cost = costModels[modelName] { modelTotal.merge(cost) }
                dayTotal.merge(modelTotal)
                if modelTotal.hasCost || modelTotal.hasTokens {
                    breakdowns.append(CostUsageDailyReport.ModelBreakdown(
                        modelName: modelName,
                        costUSD: modelTotal.hasCost ? modelTotal.cost : nil,
                        totalTokens: modelTotal.hasTokens ? modelTotal.totalTokens : nil))
                }
            }

            let sortedBreakdowns = breakdowns.sorted { lhs, rhs in
                let lhsCost = lhs.costUSD ?? -1
                let rhsCost = rhs.costUSD ?? -1
                if lhsCost != rhsCost { return lhsCost > rhsCost }
                let lhsTokens = lhs.totalTokens ?? -1
                let rhsTokens = rhs.totalTokens ?? -1
                if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }
                return lhs.modelName < rhs.modelName
            }

            return CostUsageDailyReport.Entry(
                date: date,
                inputTokens: dayTotal.sawPromptCacheMissTokens ? dayTotal.promptCacheMissTokens : nil,
                outputTokens: dayTotal.sawResponseTokens ? dayTotal.responseTokens : nil,
                cacheReadTokens: dayTotal.sawPromptCacheHitTokens ? dayTotal.promptCacheHitTokens : nil,
                cacheCreationTokens: nil,
                totalTokens: dayTotal.hasTokens ? dayTotal.totalTokens : nil,
                costUSD: dayTotal.hasCost ? dayTotal.cost : nil,
                modelsUsed: modelNames.isEmpty ? nil : modelNames,
                modelBreakdowns: sortedBreakdowns.isEmpty ? nil : sortedBreakdowns)
        }
    }

    private static func totalCost(
        from payload: DeepSeekDashboardUsageData,
        daily: [CostUsageDailyReport.Entry]) -> Double
    {
        let totalAggregate = self.aggregatesByModel(models: payload.total, kind: .cost)
            .values
            .reduce(into: DeepSeekDashboardUsageAggregate()) { result, aggregate in
                result.merge(aggregate)
            }
        if totalAggregate.hasCost {
            return totalAggregate.cost
        }
        return daily.compactMap(\.costUSD).reduce(0, +)
    }

    private static func amountTotals(
        from payload: DeepSeekDashboardUsageData,
        daily: [CostUsageDailyReport.Entry]) -> (requests: Int, tokens: Int)
    {
        let totalAggregate = self.aggregatesByModel(models: payload.total, kind: .amount)
            .values
            .reduce(into: DeepSeekDashboardUsageAggregate()) { result, aggregate in
                result.merge(aggregate)
            }
        if totalAggregate.hasRequests || totalAggregate.hasTokens {
            return (
                requests: totalAggregate.hasRequests ? totalAggregate.requestCount : 0,
                tokens: totalAggregate.hasTokens ? totalAggregate.totalTokens : 0)
        }

        let tokens = daily.compactMap(\.totalTokens).reduce(0, +)
        let requests = self.aggregatesByDateModel(days: payload.days, kind: .amount)
            .values
            .flatMap(\.values)
            .reduce(into: DeepSeekDashboardUsageAggregate()) { result, aggregate in
                result.merge(aggregate)
            }
        return (requests.requestCount, tokens)
    }

    private static func models(
        costPayload: DeepSeekDashboardUsageData,
        amountPayload: DeepSeekDashboardUsageData,
        daily: [CostUsageDailyReport.Entry]) -> [String]
    {
        var models = Set<String>()
        for item in costPayload.total + amountPayload.total {
            models.insert(item.model)
        }
        for day in costPayload.days + amountPayload.days {
            for item in day.data {
                models.insert(item.model)
            }
        }
        for entry in daily {
            if let modelsUsed = entry.modelsUsed {
                models.formUnion(modelsUsed)
            }
        }
        models.remove("")
        return models.sorted()
    }

    private static func currencyCode(from payload: DeepSeekDashboardUsageData) -> String {
        payload.currency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "CNY"
    }

    private static func aggregatesByDateModel(
        days: [DeepSeekDashboardDayUsage],
        kind: DeepSeekDashboardUsageKind) -> [String: [String: DeepSeekDashboardUsageAggregate]]
    {
        var result: [String: [String: DeepSeekDashboardUsageAggregate]] = [:]
        for day in days {
            let date = self.normalizeDayKey(day.date)
            var models = result[date] ?? [:]
            for (modelName, aggregate) in self.aggregatesByModel(models: day.data, kind: kind) {
                var existing = models[modelName] ?? DeepSeekDashboardUsageAggregate()
                existing.merge(aggregate)
                models[modelName] = existing
            }
            result[date] = models
        }
        return result
    }

    private static func aggregatesByModel(
        models: [DeepSeekDashboardModelUsage],
        kind: DeepSeekDashboardUsageKind) -> [String: DeepSeekDashboardUsageAggregate]
    {
        var result: [String: DeepSeekDashboardUsageAggregate] = [:]
        for model in models {
            var aggregate = result[model.model] ?? DeepSeekDashboardUsageAggregate()
            for usage in model.usage {
                switch kind {
                case .amount:
                    aggregate.addAmount(type: usage.type, amount: usage.amount.doubleValue)
                case .cost:
                    aggregate.addCost(usage.amount.doubleValue)
                }
            }
            result[model.model] = aggregate
        }
        return result
    }

    private static func normalizeDayKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return trimmed
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

#if os(macOS)
public enum DeepSeekCostUsageFetcher: Sendable {
    public static func loadTokenSnapshot(now: Date = Date()) async throws -> CostUsageTokenSnapshot {
        guard let token = await MainActor.run(
            resultType: String?.self,
            body: { DeepSeekPlatformTokenManager.shared.getStoredToken() })
        else {
            throw DeepSeekDashboardUsageError.missingPlatformToken
        }

        return try await DeepSeekDashboardUsageFetcher
            .fetchCurrentMonth(platformToken: token, now: now)
            .toTokenSnapshot(now: now)
    }
}
#endif

private struct DeepSeekDashboardUsageEnvelope: Decodable {
    let data: DeepSeekDashboardUsageData

    private enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        if let container, container.contains(.data) {
            self.data = try container.decode(DeepSeekDashboardUsageData.self, forKey: .data)
        } else {
            self.data = try DeepSeekDashboardUsageData(from: decoder)
        }
    }
}

private struct DeepSeekDashboardUsageData: Decodable, Sendable {
    let total: [DeepSeekDashboardModelUsage]
    let days: [DeepSeekDashboardDayUsage]
    let currency: String?

    init(total: [DeepSeekDashboardModelUsage], days: [DeepSeekDashboardDayUsage], currency: String?) {
        self.total = total
        self.days = days
        self.currency = currency
    }

    private enum CodingKeys: String, CodingKey {
        case bizData = "biz_data"
        case total
        case totals
        case days
        case daily
        case currency
    }

    init(from decoder: Decoder) throws {
        if let days = try? [DeepSeekDashboardDayUsage](from: decoder) {
            self.total = []
            self.days = days
            self.currency = Self.firstCurrency(days: days)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.bizData) {
            let wrapperCurrency = try container.decodeIfPresent(String.self, forKey: .currency)
            if let nestedArray = try? container.decode([DeepSeekDashboardUsageData].self, forKey: .bizData) {
                let nested = Self.merged(nestedArray, currency: wrapperCurrency)
                self.total = nested.total
                self.days = nested.days
                self.currency = nested.currency
                return
            }

            let nested = try container.decode(DeepSeekDashboardUsageData.self, forKey: .bizData)
            self.total = nested.total
            self.days = nested.days
            self.currency = wrapperCurrency ?? nested.currency
            return
        }

        let total = try container.decodeIfPresent([DeepSeekDashboardModelUsage].self, forKey: .total)
        let totals = try container.decodeIfPresent([DeepSeekDashboardModelUsage].self, forKey: .totals)
        self.total = total ?? totals ?? []

        let days = try container.decodeIfPresent([DeepSeekDashboardDayUsage].self, forKey: .days)
        let daily = try container.decodeIfPresent([DeepSeekDashboardDayUsage].self, forKey: .daily)
        self.days = days ?? daily ?? []
        self.currency =
            try container.decodeIfPresent(String.self, forKey: .currency)
            ?? Self.firstCurrency(models: self.total)
            ?? Self.firstCurrency(days: self.days)
    }

    private static func merged(
        _ values: [DeepSeekDashboardUsageData],
        currency: String?) -> DeepSeekDashboardUsageData
    {
        DeepSeekDashboardUsageData(
            total: values.flatMap(\.total),
            days: values.flatMap(\.days),
            currency: currency ?? values.compactMap(\.currency).first)
    }

    private static func firstCurrency(models: [DeepSeekDashboardModelUsage]) -> String? {
        for model in models {
            if let currency = model.currency?.nilIfEmpty { return currency }
            for usage in model.usage {
                if let currency = usage.currency?.nilIfEmpty { return currency }
            }
        }
        return nil
    }

    private static func firstCurrency(days: [DeepSeekDashboardDayUsage]) -> String? {
        for day in days {
            if let currency = day.currency?.nilIfEmpty { return currency }
            if let currency = self.firstCurrency(models: day.data) { return currency }
        }
        return nil
    }
}

private struct DeepSeekDashboardDayUsage: Decodable, Sendable {
    let date: String
    let data: [DeepSeekDashboardModelUsage]
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case date
        case day
        case data
        case models
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decodeIfPresent(String.self, forKey: .date)
        let day = try container.decodeIfPresent(String.self, forKey: .day)
        self.date = date ?? day ?? ""

        let data = try container.decodeIfPresent([DeepSeekDashboardModelUsage].self, forKey: .data)
        let models = try container.decodeIfPresent([DeepSeekDashboardModelUsage].self, forKey: .models)
        self.data = data ?? models ?? []
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
    }
}

private struct DeepSeekDashboardModelUsage: Decodable, Sendable {
    let model: String
    let usage: [DeepSeekDashboardUsageItem]
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case model
        case modelName = "model_name"
        case modelCode = "model_code"
        case usage
        case data
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let model = try container.decodeIfPresent(String.self, forKey: .model)
        let modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
        let modelCode = try container.decodeIfPresent(String.self, forKey: .modelCode)
        self.model = model ?? modelName ?? modelCode ?? "unknown"

        let usage = try container.decodeIfPresent([DeepSeekDashboardUsageItem].self, forKey: .usage)
        let data = try container.decodeIfPresent([DeepSeekDashboardUsageItem].self, forKey: .data)
        self.usage = usage ?? data ?? []
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
    }
}

private struct DeepSeekDashboardUsageItem: Decodable, Sendable {
    let type: String
    let amount: DeepSeekDashboardFlexibleNumber
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case amount
        case currency
    }
}

private struct DeepSeekDashboardFlexibleNumber: Decodable, Sendable {
    let doubleValue: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self.doubleValue = doubleValue
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self.doubleValue = Double(intValue)
            return
        }
        let stringValue = try container.decode(String.self)
        let normalized = stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard let doubleValue = Double(normalized) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected numeric amount.")
        }
        self.doubleValue = doubleValue
    }
}

private enum DeepSeekDashboardUsageKind {
    case amount
    case cost
}

private struct DeepSeekDashboardUsageAggregate {
    var requestCount = 0
    var sawRequests = false
    var responseTokens = 0
    var sawResponseTokens = false
    var promptCacheMissTokens = 0
    var sawPromptCacheMissTokens = false
    var promptCacheHitTokens = 0
    var sawPromptCacheHitTokens = false
    var cost = 0.0
    var hasCost = false

    var hasTokens: Bool {
        self.sawResponseTokens || self.sawPromptCacheMissTokens || self.sawPromptCacheHitTokens
    }

    var hasRequests: Bool {
        self.sawRequests
    }

    var totalTokens: Int {
        self.responseTokens + self.promptCacheMissTokens + self.promptCacheHitTokens
    }

    mutating func addAmount(type: String, amount: Double) {
        let normalized = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let intAmount = Int(amount.rounded())
        switch normalized {
        case "REQUEST":
            self.requestCount += intAmount
            self.sawRequests = true
        case "RESPONSE_TOKEN":
            self.responseTokens += intAmount
            self.sawResponseTokens = true
        case "PROMPT_CACHE_MISS_TOKEN":
            self.promptCacheMissTokens += intAmount
            self.sawPromptCacheMissTokens = true
        case "PROMPT_CACHE_HIT_TOKEN":
            self.promptCacheHitTokens += intAmount
            self.sawPromptCacheHitTokens = true
        default:
            break
        }
    }

    mutating func addCost(_ amount: Double) {
        self.cost += amount
        self.hasCost = true
    }

    mutating func merge(_ other: DeepSeekDashboardUsageAggregate) {
        self.requestCount += other.requestCount
        self.sawRequests = self.sawRequests || other.sawRequests
        self.responseTokens += other.responseTokens
        self.sawResponseTokens = self.sawResponseTokens || other.sawResponseTokens
        self.promptCacheMissTokens += other.promptCacheMissTokens
        self.sawPromptCacheMissTokens = self.sawPromptCacheMissTokens || other.sawPromptCacheMissTokens
        self.promptCacheHitTokens += other.promptCacheHitTokens
        self.sawPromptCacheHitTokens = self.sawPromptCacheHitTokens || other.sawPromptCacheHitTokens
        self.cost += other.cost
        self.hasCost = self.hasCost || other.hasCost
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
