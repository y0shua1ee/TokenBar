import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public enum OpenRouterActivityUsageError: LocalizedError, Equatable, Sendable {
    case missingManagementKey
    case invalidCredentials
    case authenticationRejected
    case permissionDenied
    case rateLimited
    case apiError(Int)
    case invalidResponse
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .missingManagementKey:
            "OpenRouter account activity requires a management key. " +
                "Set OPENROUTER_MANAGEMENT_KEY or add one in Settings."
        case .invalidCredentials:
            "The OpenRouter management key is empty or invalid."
        case .authenticationRejected:
            "OpenRouter rejected the management key."
        case .permissionDenied:
            "OpenRouter Activity requires a management key; ordinary API keys cannot access account activity."
        case .rateLimited:
            "OpenRouter is rate limiting Activity requests. Please try again later."
        case let .apiError(statusCode):
            "OpenRouter Activity API returned HTTP \(statusCode)."
        case .invalidResponse:
            "OpenRouter returned an invalid Activity response."
        case let .networkError(message):
            "OpenRouter Activity network error: \(message)"
        }
    }
}

public enum OpenRouterActivityUsageFetcher {
    public static let activityURL: URL = {
        guard let url = URL(string: "https://openrouter.ai/api/v1/activity") else {
            preconditionFailure("OpenRouter Activity URL must be valid")
        }
        return url
    }()

    public static let maximumHistoryDays = 30
    private static let requestTimeoutSeconds: TimeInterval = 15

    public static func loadTokenSnapshot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date(),
        historyDays: Int = Self.maximumHistoryDays,
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) async throws -> CostUsageTokenSnapshot
    {
        guard let managementKey = OpenRouterSettingsReader.managementKey(environment: environment) else {
            throw OpenRouterActivityUsageError.missingManagementKey
        }
        let report = try await self.loadDailyReport(
            managementKey: managementKey,
            now: now,
            historyDays: historyDays,
            transport: transport)
        return report.toTokenSnapshot(managementKey: managementKey, now: now)
    }

    public static func loadDailyReport(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date(),
        historyDays: Int = Self.maximumHistoryDays,
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) async throws -> OpenRouterActivityUsageReport
    {
        guard let managementKey = OpenRouterSettingsReader.managementKey(environment: environment) else {
            throw OpenRouterActivityUsageError.missingManagementKey
        }
        return try await self.loadDailyReport(
            managementKey: managementKey,
            now: now,
            historyDays: historyDays,
            transport: transport)
    }

    public static func loadDailyReport(
        managementKey: String,
        now: Date = Date(),
        historyDays: Int = Self.maximumHistoryDays,
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) async throws -> OpenRouterActivityUsageReport
    {
        let key = managementKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw OpenRouterActivityUsageError.invalidCredentials }

        var request = URLRequest(url: self.activityURL)
        request.httpMethod = "GET"
        request.timeoutInterval = self.requestTimeoutSeconds
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try Task.checkCancellation()
        let response: ProviderHTTPResponse
        do {
            response = try await transport.response(for: request)
        } catch {
            try self.propagateCancellation(error)
            throw OpenRouterActivityUsageError.networkError(error.localizedDescription)
        }
        try Task.checkCancellation()

        switch response.statusCode {
        case 200:
            break
        case 401:
            throw OpenRouterActivityUsageError.authenticationRejected
        case 403:
            throw OpenRouterActivityUsageError.permissionDenied
        case 429:
            throw OpenRouterActivityUsageError.rateLimited
        default:
            throw OpenRouterActivityUsageError.apiError(response.statusCode)
        }

        let decoded: OpenRouterActivityResponse
        do {
            decoded = try JSONDecoder().decode(OpenRouterActivityResponse.self, from: response.data)
        } catch {
            throw OpenRouterActivityUsageError.invalidResponse
        }
        try Task.checkCancellation()
        return self.report(from: decoded.data, now: now, historyDays: historyDays)
    }

    public static func report(
        from items: [OpenRouterActivityItem],
        now: Date = Date(),
        historyDays: Int = Self.maximumHistoryDays) -> OpenRouterActivityUsageReport
    {
        let days = self.clampedHistoryDays(historyDays)
        let calendar = self.utcCalendar
        let today = calendar.startOfDay(for: now)
        let oldest = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        var accumulators: [String: DayAccumulator] = [:]

        for item in items {
            guard let day = self.normalizedDay(from: item.date, calendar: calendar),
                  day.date >= oldest,
                  day.date < today
            else { continue }
            var accumulator = accumulators[day.key] ?? DayAccumulator()
            accumulator.add(item)
            accumulators[day.key] = accumulator
        }

        let keys = accumulators.keys.sorted()
        let daily = keys.compactMap { key in accumulators[key]?.entry(date: key) }
        let requestsByDate = keys.reduce(into: [String: Int]()) { result, key in
            guard let accumulator = accumulators[key], accumulator.sawRequests else { return }
            result[key] = accumulator.requests
        }
        let reasoningTokensByDate = keys.reduce(into: [String: Int]()) { result, key in
            guard let accumulator = accumulators[key], accumulator.sawReasoningTokens else { return }
            result[key] = accumulator.reasoningTokens
        }
        let reasoningTokensByModelByDate = keys.reduce(into: [String: [String: Int]]()) { result, key in
            guard let accumulator = accumulators[key] else { return }
            let values = accumulator.modelAccumulators.reduce(into: [String: Int]()) { models, pair in
                guard pair.value.sawReasoningTokens else { return }
                models[pair.key] = pair.value.reasoningTokens
            }
            if !values.isEmpty { result[key] = values }
        }
        return OpenRouterActivityUsageReport(
            daily: daily,
            requestsByDate: requestsByDate,
            reasoningTokensByDate: reasoningTokensByDate,
            reasoningTokensByModelByDate: reasoningTokensByModelByDate,
            historyDays: days,
            updatedAt: now)
    }

    static func clampedHistoryDays(_ historyDays: Int) -> Int {
        min(self.maximumHistoryDays, max(1, historyDays))
    }

    /// One-way cache scope discriminator; the raw management key must never be persisted or emitted.
    public static func credentialFingerprint(_ managementKey: String) -> String {
        let key = managementKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let material = "\(TokenBarIdentity.persistenceNamespace).openrouter.management.v1\0\(key)"
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return calendar
    }

    private static func normalizedDay(from rawValue: String, calendar: Calendar) -> (key: String, date: Date)? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 10 else { return nil }
        let prefix = String(value.prefix(10))
        let parts = prefix.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else { return nil }
        return (String(format: "%04d-%02d-%02d", year, month, day), date)
    }

    private static func propagateCancellation(_ error: Error) throws {
        if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
            throw CancellationError()
        }
    }

    private struct DayAccumulator {
        var inputTokens = 0
        var outputTokens = 0
        var totalTokens = 0
        var reasoningTokens = 0
        var requests = 0
        var costUSD = 0.0
        var sawInputTokens = false
        var sawOutputTokens = false
        var sawTotalTokens = false
        var sawReasoningTokens = false
        var sawRequests = false
        var sawCost = false
        var modelAccumulators: [String: ModelAccumulator] = [:]

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
            if let value = item.reasoningTokensValue {
                self.reasoningTokens += value
                self.sawReasoningTokens = true
            }
            if let value = item.requestCountValue {
                self.requests += value
                self.sawRequests = true
            }
            if let value = item.costUSDValue {
                self.costUSD += value
                self.sawCost = true
            }
            guard let modelName = item.displayModelName else { return }
            var accumulator = self.modelAccumulators[modelName] ?? ModelAccumulator()
            accumulator.add(item)
            self.modelAccumulators[modelName] = accumulator
        }

        func entry(date: String) -> CostUsageDailyReport.Entry? {
            guard self.sawRequests || self.sawTotalTokens || self.sawReasoningTokens || self.sawCost else { return nil }
            let breakdowns = self.modelAccumulators.map { modelName, accumulator in
                accumulator.breakdown(modelName: modelName)
            }.sorted { lhs, rhs in
                if (lhs.costUSD ?? -1) != (rhs.costUSD ?? -1) {
                    return (lhs.costUSD ?? -1) > (rhs.costUSD ?? -1)
                }
                if (lhs.totalTokens ?? -1) != (rhs.totalTokens ?? -1) {
                    return (lhs.totalTokens ?? -1) > (rhs.totalTokens ?? -1)
                }
                return lhs.modelName < rhs.modelName
            }
            return CostUsageDailyReport.Entry(
                date: date,
                inputTokens: self.sawInputTokens ? self.inputTokens : nil,
                outputTokens: self.sawOutputTokens ? self.outputTokens : nil,
                reasoningTokens: self.sawReasoningTokens ? self.reasoningTokens : nil,
                totalTokens: self.sawTotalTokens ? self.totalTokens : nil,
                requestCount: self.sawRequests ? self.requests : nil,
                costUSD: self.sawCost ? self.costUSD : nil,
                modelsUsed: breakdowns.isEmpty ? nil : breakdowns.map(\.modelName).sorted(),
                modelBreakdowns: breakdowns.isEmpty ? nil : breakdowns)
        }
    }

    private struct ModelAccumulator {
        var totalTokens = 0
        var reasoningTokens = 0
        var requests = 0
        var costUSD = 0.0
        var sawTotalTokens = false
        var sawReasoningTokens = false
        var sawRequests = false
        var sawCost = false

        mutating func add(_ item: OpenRouterActivityItem) {
            if let value = item.totalTokensValue {
                self.totalTokens += value
                self.sawTotalTokens = true
            }
            if let value = item.reasoningTokensValue {
                self.reasoningTokens += value
                self.sawReasoningTokens = true
            }
            if let value = item.requestCountValue {
                self.requests += value
                self.sawRequests = true
            }
            if let value = item.costUSDValue {
                self.costUSD += value
                self.sawCost = true
            }
        }

        func breakdown(modelName: String) -> CostUsageDailyReport.ModelBreakdown {
            CostUsageDailyReport.ModelBreakdown(
                modelName: modelName,
                costUSD: self.sawCost ? self.costUSD : nil,
                totalTokens: self.sawTotalTokens ? self.totalTokens : nil,
                reasoningTokens: self.sawReasoningTokens ? self.reasoningTokens : nil,
                requestCount: self.sawRequests ? self.requests : nil)
        }
    }
}
