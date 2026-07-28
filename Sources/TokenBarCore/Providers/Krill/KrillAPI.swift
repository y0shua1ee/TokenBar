import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP client for Krill's same-origin API exposed by www.krill-ai.net.
/// Uses JWT bearer token authentication (extracted from WebView login).
public enum KrillAPIClient: Sendable {
    public static let baseURL = "https://www.krill-ai.net"
    static let dashboardURL = "\(baseURL)/app"
    static let loginURL = URL(string: "\(baseURL)/login")!
    private static let requestTimeout: TimeInterval = 15

    // MARK: - Credits

    public static func fetchCredits(jwt: String) async throws -> KrillCreditsResponse {
        let url = self.urlFor("/api/credits")
        let data = try await get(url: url, jwt: jwt)
        return try JSONDecoder().decode(KrillCreditsResponse.self, from: data)
    }

    // MARK: - Subscription

    public static func fetchSubscription(jwt: String) async throws -> KrillSubscriptionResponse {
        let url = self.urlFor("/api/subscription")
        let data = try await get(url: url, jwt: jwt)
        return try JSONDecoder().decode(KrillSubscriptionResponse.self, from: data)
    }

    public static func fetchActiveSubscriptionDailyQuota(
        jwt: String) async throws -> KrillActiveSubscriptionDailyQuotaResponse
    {
        let url = self.urlFor("/api/subscription/daily-quota/active")
        let data = try await get(url: url, jwt: jwt)
        return try JSONDecoder().decode(KrillActiveSubscriptionDailyQuotaResponse.self, from: data)
    }

    // MARK: - Stats

    public static func fetchStats(
        jwt: String,
        startTime: Date? = nil,
        endTime: Date? = nil) async throws -> KrillStatsResponse
    {
        let url = self.urlFor("/api/request-logs/stats")
        var body: [String: Any] = [:]
        if let startTime {
            body["start_time"] = self.iso8601String(startTime)
        }
        if let endTime {
            body["end_time"] = self.iso8601String(endTime)
        }

        let data = try await post(url: url, jwt: jwt, body: jsonBody(body))
        return try JSONDecoder().decode(KrillStatsResponse.self, from: data)
    }

    public static func fetchModelStats(
        jwt: String,
        startTime: Date,
        endTime: Date) async throws -> KrillModelStatsResponse
    {
        let url = self.urlFor("/api/request-logs/model-stats")
        let body: [String: Any] = [
            "start_time": self.iso8601String(startTime),
            "end_time": self.iso8601String(endTime),
        ]
        let data = try await post(url: url, jwt: jwt, body: jsonBody(body))
        return try JSONDecoder().decode(KrillModelStatsResponse.self, from: data)
    }

    // MARK: - Request Logs

    public static func fetchRequestLogs(
        jwt: String,
        startTime: Date,
        endTime: Date,
        page: Int = 1,
        pageSize: Int = 100) async throws -> KrillRequestLogsResponse
    {
        let url = self.urlFor("/api/request-logs")
        let body: [String: Any] = [
            "start_time": self.iso8601String(startTime),
            "end_time": self.iso8601String(endTime),
            "page": max(page, 1),
            "page_size": max(pageSize, 1),
        ]
        let data = try await post(url: url, jwt: jwt, body: jsonBody(body))
        return try JSONDecoder().decode(KrillRequestLogsResponse.self, from: data)
    }

    // MARK: - Models

    public static func fetchModels(jwt: String) async throws -> [String] {
        let url = self.urlFor("/api/models")
        let data = try await get(url: url, jwt: jwt)
        let response = try JSONDecoder().decode(KrillModelsResponse.self, from: data)
        return response.data ?? []
    }

    // MARK: - Internal

    private static func urlFor(_ path: String) -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            fatalError("Invalid Krill API URL: \(self.baseURL)\(path)")
        }
        return url
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func jsonBody(_ body: [String: Any]) throws -> String {
        guard !body.isEmpty else { return "{}" }
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func get(url: URL, jwt: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw KrillAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }

    private static func post(url: URL, jwt: String, body: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw KrillAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }
}

// MARK: - Errors

public enum KrillAPIError: LocalizedError, Sendable {
    case httpError(Int)
    case missingJWT
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case let .httpError(code):
            "Krill API HTTP \(code)"
        case .missingJWT:
            "Krill JWT not found. Please log in."
        case let .parseError(msg):
            "Krill parse error: \(msg)"
        }
    }
}
