import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OpenRouterActivityUsageError: LocalizedError, Sendable {
    case missingManagementKey
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingManagementKey:
            "OpenRouter Activity key missing. Set OPENROUTER_MANAGEMENT_KEY or OPENROUTER_ACTIVITY_API_KEY, or paste a management key in OpenRouter settings."
        case .invalidCredentials:
            "Invalid OpenRouter Activity credentials."
        case let .networkError(message):
            "OpenRouter Activity network error: \(message)"
        case let .apiError(message):
            "OpenRouter Activity API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse OpenRouter Activity response: \(message)"
        }
    }
}

public struct OpenRouterActivityResponse: Decodable, Sendable, Equatable {
    public let data: [OpenRouterActivityItem]
}

public struct OpenRouterActivityItem: Decodable, Sendable, Equatable {
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
        self.byokUsageInference = try Self.decodeFlexibleDouble(container, forKey: .byokUsageInference)
        self.completionTokens = try Self.decodeFlexibleInt(container, forKey: .completionTokens)
        self.date = try container.decode(String.self, forKey: .date)
        self.endpointID = try container.decodeIfPresent(String.self, forKey: .endpointID)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.modelPermaslug = try container.decodeIfPresent(String.self, forKey: .modelPermaslug)
        self.promptTokens = try Self.decodeFlexibleInt(container, forKey: .promptTokens)
        self.providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        self.reasoningTokens = try Self.decodeFlexibleInt(container, forKey: .reasoningTokens)
        self.requests = try Self.decodeFlexibleInt(container, forKey: .requests)
        self.usage = try Self.decodeFlexibleDouble(container, forKey: .usage)
    }

    var inputTokensValue: Int? {
        self.promptTokens
    }

    var outputTokensValue: Int? {
        let completion = self.completionTokens ?? 0
        let reasoning = self.reasoningTokens ?? 0
        guard self.completionTokens != nil || self.reasoningTokens != nil else { return nil }
        return completion + reasoning
    }

    var totalTokensValue: Int? {
        let prompt = self.promptTokens ?? 0
        let completion = self.completionTokens ?? 0
        let reasoning = self.reasoningTokens ?? 0
        guard self.promptTokens != nil || self.completionTokens != nil || self.reasoningTokens != nil else { return nil }
        return prompt + completion + reasoning
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
        forKey key: CodingKeys) throws -> Int?
    {
        if let value = try container.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try container.decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intValue = Int(trimmed) { return intValue }
            if let doubleValue = Double(trimmed) { return Int(doubleValue) }
        }
        return nil
    }

    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys) throws -> Double?
    {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try container.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

public struct OpenRouterActivityUsageReport: Sendable, Equatable {
    public let daily: [CostUsageDailyReport.Entry]
    public let requestsByDate: [String: Int]
    public let updatedAt: Date

    public init(daily: [CostUsageDailyReport.Entry], requestsByDate: [String: Int], updatedAt: Date) {
        self.daily = daily
        self.requestsByDate = requestsByDate
        self.updatedAt = updatedAt
    }

    public var totalRequests: Int? {
        let total = self.requestsByDate.values.reduce(0, +)
        return total > 0 ? total : nil
    }

    public func toTokenSnapshot(now: Date? = nil) -> CostUsageTokenSnapshot {
        let report = CostUsageDailyReport(data: self.daily, summary: Self.summary(from: self.daily))
        let snapshot = CostUsageFetcher.tokenSnapshot(from: report, now: now ?? self.updatedAt)
        let currentDay = self.daily.max { lhs, rhs in
            let lDate = CostUsageDateParser.parse(lhs.date) ?? .distantPast
            let rDate = CostUsageDateParser.parse(rhs.date) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            return lhs.date < rhs.date
        }
        let currentRequests = currentDay.flatMap { entry -> Int? in
            let requests = self.requestsByDate[entry.date] ?? 0
            return requests > 0 ? requests : nil
        }
        return CostUsageTokenSnapshot(
            sessionTokens: snapshot.sessionTokens,
            sessionCostUSD: snapshot.sessionCostUSD,
            sessionRequests: currentRequests,
            last30DaysTokens: snapshot.last30DaysTokens,
            last30DaysCostUSD: snapshot.last30DaysCostUSD,
            last30DaysRequests: self.totalRequests,
            costCurrencyCode: "USD",
            daily: snapshot.daily,
            updatedAt: snapshot.updatedAt)
    }

    private static func summary(from entries: [CostUsageDailyReport.Entry]) -> CostUsageDailyReport.Summary? {
        guard !entries.isEmpty else { return nil }
        var inputTokens = 0
        var outputTokens = 0
        var totalTokens = 0
        var totalCost = 0.0
        var sawInput = false
        var sawOutput = false
        var sawTokens = false
        var sawCost = false

        for entry in entries {
            if let value = entry.inputTokens {
                inputTokens += value
                sawInput = true
            }
            if let value = entry.outputTokens {
                outputTokens += value
                sawOutput = true
            }
            if let value = entry.totalTokens {
                totalTokens += value
                sawTokens = true
            }
            if let value = entry.costUSD {
                totalCost += value
                sawCost = true
            }
        }

        return CostUsageDailyReport.Summary(
            totalInputTokens: sawInput ? inputTokens : nil,
            totalOutputTokens: sawOutput ? outputTokens : nil,
            totalTokens: sawTokens ? totalTokens : nil,
            totalCostUSD: sawCost ? totalCost : nil)
    }
}

public enum OpenRouterActivityUsageFetcher: Sendable {
    private static let activityRequestTimeoutSeconds: TimeInterval = 15

    public static func loadTokenSnapshot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()) async throws -> CostUsageTokenSnapshot
    {
        let report = try await self.loadDailyReport(environment: environment, now: now)
        return report.toTokenSnapshot(now: now)
    }

    public static func loadDailyReport(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()) async throws -> OpenRouterActivityUsageReport
    {
        guard let key = OpenRouterSettingsReader.activityAPIKey(environment: environment) else {
            throw OpenRouterActivityUsageError.missingManagementKey
        }
        return try await self.loadDailyReport(managementKey: key, environment: environment, now: now)
    }

    public static func loadDailyReport(
        managementKey: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()) async throws -> OpenRouterActivityUsageReport
    {
        guard !managementKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenRouterActivityUsageError.invalidCredentials
        }

        let baseURL = OpenRouterSettingsReader.apiURL(environment: environment)
        let activityURL = baseURL.appendingPathComponent("activity")
        var request = URLRequest(url: activityURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(managementKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = self.activityRequestTimeoutSeconds
        if let referer = OpenRouterSettingsReader.cleaned(environment["OPENROUTER_HTTP_REFERER"]) {
            request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        }
        let title = OpenRouterSettingsReader.cleaned(environment["OPENROUTER_X_TITLE"]) ?? "TokenBar"
        request.setValue(title, forHTTPHeaderField: "X-Title")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenRouterActivityUsageError.networkError("Invalid response")
            }
            guard httpResponse.statusCode == 200 else {
                throw OpenRouterActivityUsageError.apiError(self.apiErrorMessage(statusCode: httpResponse.statusCode))
            }
            let decoded = try JSONDecoder().decode(OpenRouterActivityResponse.self, from: data)
            return self.report(from: decoded.data, now: now)
        } catch let error as OpenRouterActivityUsageError {
            throw error
        } catch let error as DecodingError {
            throw OpenRouterActivityUsageError.parseFailed(error.localizedDescription)
        } catch {
            throw OpenRouterActivityUsageError.networkError(error.localizedDescription)
        }
    }

    public static func report(
        from items: [OpenRouterActivityItem],
        now: Date = Date()) -> OpenRouterActivityUsageReport
    {
        var dayAccumulators: [String: DayAccumulator] = [:]
        for item in items {
            let day = item.date.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !day.isEmpty else { continue }
            var accumulator = dayAccumulators[day] ?? DayAccumulator()
            accumulator.add(item)
            dayAccumulators[day] = accumulator
        }

        let daily = dayAccumulators.keys.sorted().compactMap { day -> CostUsageDailyReport.Entry? in
            dayAccumulators[day]?.entry(date: day)
        }
        let requestsByDate = dayAccumulators.reduce(into: [String: Int]()) { partial, pair in
            if pair.value.requests > 0 {
                partial[pair.key] = pair.value.requests
            }
        }
        return OpenRouterActivityUsageReport(daily: daily, requestsByDate: requestsByDate, updatedAt: now)
    }

    private static func apiErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 401:
            "HTTP 401: authentication required"
        case 403:
            "HTTP 403: OpenRouter Activity requires a management key"
        default:
            "HTTP \(statusCode)"
        }
    }

    private struct DayAccumulator {
        var inputTokens = 0
        var outputTokens = 0
        var totalTokens = 0
        var costUSD = 0.0
        var requests = 0
        var sawInputTokens = false
        var sawOutputTokens = false
        var sawTotalTokens = false
        var sawCost = false
        var modelsUsed: Set<String> = []
        var modelBreakdowns: [String: ModelAccumulator] = [:]

        mutating func add(_ item: OpenRouterActivityItem) {
            if let value = item.inputTokensValue {
                self.inputTokens += value
                self.sawInputTokens = true
            }
            if let value = item.outputTokensValue {
                self.outputTokens += value
                self.sawOutputTokens = true
            }
            if let value = item.totalTokensValue {
                self.totalTokens += value
                self.sawTotalTokens = true
            }
            if let value = item.costUSDValue {
                self.costUSD += value
                self.sawCost = true
            }
            if let requests = item.requests, requests > 0 {
                self.requests += requests
            }
            guard let modelName = item.displayModelName else { return }
            self.modelsUsed.insert(modelName)
            var breakdown = self.modelBreakdowns[modelName] ?? ModelAccumulator()
            breakdown.add(item)
            self.modelBreakdowns[modelName] = breakdown
        }

        func entry(date: String) -> CostUsageDailyReport.Entry? {
            guard self.requests > 0 || self.sawTotalTokens || self.sawCost else { return nil }
            let breakdowns = Self.sortedBreakdowns(
                self.modelBreakdowns.map { modelName, accumulator in
                    CostUsageDailyReport.ModelBreakdown(
                        modelName: modelName,
                        costUSD: accumulator.sawCost ? accumulator.costUSD : nil,
                        totalTokens: accumulator.sawTokens ? accumulator.totalTokens : nil)
                })
            return CostUsageDailyReport.Entry(
                date: date,
                inputTokens: self.sawInputTokens ? self.inputTokens : nil,
                outputTokens: self.sawOutputTokens ? self.outputTokens : nil,
                totalTokens: self.sawTotalTokens ? self.totalTokens : nil,
                costUSD: self.sawCost ? self.costUSD : nil,
                modelsUsed: self.modelsUsed.isEmpty ? nil : self.modelsUsed.sorted(),
                modelBreakdowns: breakdowns.isEmpty ? nil : breakdowns)
        }

        private static func sortedBreakdowns(_ breakdowns: [CostUsageDailyReport.ModelBreakdown])
            -> [CostUsageDailyReport.ModelBreakdown]
        {
            breakdowns.sorted { lhs, rhs in
                let lhsCost = lhs.costUSD ?? -1
                let rhsCost = rhs.costUSD ?? -1
                if lhsCost != rhsCost { return lhsCost > rhsCost }
                let lhsTokens = lhs.totalTokens ?? -1
                let rhsTokens = rhs.totalTokens ?? -1
                if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }
                return lhs.modelName < rhs.modelName
            }
        }
    }

    private struct ModelAccumulator {
        var totalTokens = 0
        var costUSD = 0.0
        var sawTokens = false
        var sawCost = false

        mutating func add(_ item: OpenRouterActivityItem) {
            if let tokens = item.totalTokensValue {
                self.totalTokens += tokens
                self.sawTokens = true
            }
            if let cost = item.costUSDValue {
                self.costUSD += cost
                self.sawCost = true
            }
        }
    }
}
