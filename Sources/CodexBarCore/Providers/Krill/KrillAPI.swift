import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP client for Krill internal API (api.krill-ai.com).
/// Uses JWT bearer token authentication (extracted from WebView login).
public enum KrillAPIClient: Sendable {
    public static let baseURL = "https://api.krill-ai.com"
    private static let requestTimeout: TimeInterval = 15

    // MARK: - Credits

    public static func fetchCredits(jwt: String) async throws -> KrillCreditsResponse {
        let url = urlFor("/api/credits")
        let data = try await get(url: url, jwt: jwt)
        return try JSONDecoder().decode(KrillCreditsResponse.self, from: data)
    }

    // MARK: - Subscription

    public static func fetchSubscription(jwt: String) async throws -> KrillSubscriptionResponse {
        let url = urlFor("/api/subscription")
        let data = try await get(url: url, jwt: jwt)
        return try JSONDecoder().decode(KrillSubscriptionResponse.self, from: data)
    }

    // MARK: - Stats

    public static func fetchStats(jwt: String) async throws -> KrillStatsResponse {
        let url = urlFor("/api/request-logs/stats")
        let data = try await post(url: url, jwt: jwt, body: "{}")
        return try JSONDecoder().decode(KrillStatsResponse.self, from: data)
    }

    // MARK: - Models

    public static func fetchModels(jwt: String) async throws -> [String] {
        let url = urlFor("/api/models")
        let data = try await get(url: url, jwt: jwt)
        let response = try JSONDecoder().decode(KrillModelsResponse.self, from: data)
        return response.data ?? []
    }

    // MARK: - Internal

    private static func urlFor(_ path: String) -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            fatalError("Invalid Krill API URL: \(baseURL)\(path)")
        }
        return url
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
