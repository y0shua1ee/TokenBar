import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct KrillAPIClient: Sendable {
    public static let baseURL = URL(string: "https://www.krill-ai.net")!
    public static let dashboardURL = Self.baseURL.appending(path: "app")
    public static let loginURL = Self.baseURL.appending(path: "login")

    private let baseURL: URL
    private let transport: any ProviderHTTPTransport
    private let requestTimeout: TimeInterval

    public init(
        baseURL: URL = Self.baseURL,
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared,
        requestTimeout: TimeInterval = 15)
    {
        self.baseURL = baseURL
        self.transport = transport
        self.requestTimeout = max(1, requestTimeout)
    }

    public func fetchCredits(jwt: String) async throws -> KrillCreditsResponse {
        let path = "/api/credits"
        let response: KrillCreditsResponse = try await self.get(path: path, jwt: jwt)
        return try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
    }

    public func fetchSubscription(jwt: String) async throws -> KrillSubscriptionResponse {
        let path = "/api/subscription"
        let response: KrillSubscriptionResponse = try await self.get(path: path, jwt: jwt)
        return try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
    }

    public func fetchActiveSubscriptionDailyQuota(
        jwt: String) async throws -> KrillActiveSubscriptionDailyQuotaResponse
    {
        let path = "/api/subscription/daily-quota/active"
        let response: KrillActiveSubscriptionDailyQuotaResponse = try await self.get(path: path, jwt: jwt)
        return try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
    }

    public func fetchStats(
        jwt: String,
        startTime: Date? = nil,
        endTime: Date? = nil) async throws -> KrillStatsResponse
    {
        let body = KrillStatsRequest(
            startTime: startTime.map(Self.iso8601String),
            endTime: endTime.map(Self.iso8601String))
        let path = "/api/request-logs/stats"
        let response: KrillStatsResponse = try await self.post(
            path: path,
            jwt: jwt,
            body: body)
        return try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
    }

    public func fetchModelStats(
        jwt: String,
        startTime: Date,
        endTime: Date) async throws -> KrillModelStatsResponse
    {
        let body = KrillRangeRequest(
            startTime: Self.iso8601String(startTime),
            endTime: Self.iso8601String(endTime))
        let path = "/api/request-logs/model-stats"
        let response: KrillModelStatsResponse = try await self.post(
            path: path,
            jwt: jwt,
            body: body)
        return try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
    }

    public func fetchModels(jwt: String) async throws -> [String] {
        let path = "/api/models"
        let response: KrillModelsResponse = try await self.get(path: path, jwt: jwt)
        _ = try Self.requireSuccess(response, succeeded: response.success, endpoint: path)
        return response.data ?? []
    }

    private func get<Response: Decodable>(
        path: String,
        jwt: String) async throws -> Response
    {
        var request = try self.request(path: path, jwt: jwt)
        request.httpMethod = "GET"
        return try await self.send(request, endpoint: path)
    }

    private func post<Response: Decodable>(
        path: String,
        jwt: String,
        body: some Encodable) async throws -> Response
    {
        var request = try self.request(path: path, jwt: jwt)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await self.send(request, endpoint: path)
    }

    private func request(path: String, jwt: String) throws -> URLRequest {
        let token = jwt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw KrillJWTError.missing }
        guard path.hasPrefix("/"),
              let url = URL(string: path, relativeTo: self.baseURL)?.absoluteURL,
              url.scheme == self.baseURL.scheme,
              url.host == self.baseURL.host
        else {
            throw KrillAPIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = self.requestTimeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest, endpoint: String) async throws -> Response {
        try Task.checkCancellation()
        let response: ProviderHTTPResponse
        do {
            response = try await self.transport.response(for: request)
        } catch {
            try KrillCancellation.propagate(error)
            throw error
        }
        try Task.checkCancellation()
        guard response.statusCode == 200 else {
            throw KrillAPIError.status(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: response.data)
        } catch {
            throw KrillAPIError.invalidResponse(endpoint)
        }
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func requireSuccess<Response>(
        _ response: Response,
        succeeded: Bool,
        endpoint: String) throws -> Response
    {
        guard succeeded else { throw KrillAPIError.invalidResponse(endpoint) }
        return response
    }
}

public enum KrillAPIError: LocalizedError, Equatable, Sendable {
    case invalidEndpoint
    case authenticationRequired(Int)
    case rateLimited
    case serverError(Int)
    case httpStatus(Int)
    case invalidResponse(String)

    static func status(_ code: Int) -> Self {
        switch code {
        case 401, 403: .authenticationRequired(code)
        case 429: .rateLimited
        case 500...599: .serverError(code)
        default: .httpStatus(code)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Krill API endpoint is invalid."
        case .authenticationRequired:
            "Krill login has expired or is not authorized. Please sign in again."
        case .rateLimited:
            "Krill is rate limiting requests. Please try again later."
        case let .serverError(code):
            "Krill is temporarily unavailable (HTTP \(code))."
        case let .httpStatus(code):
            "Krill API returned HTTP \(code)."
        case let .invalidResponse(endpoint):
            "Krill returned an invalid \(endpoint) response."
        }
    }
}

enum KrillCancellation {
    static func propagate(_ error: Error) throws {
        if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
            throw CancellationError()
        }
    }
}

private struct KrillStatsRequest: Encodable {
    let startTime: String?
    let endTime: String?

    private enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

private struct KrillRangeRequest: Encodable {
    let startTime: String
    let endTime: String

    private enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
