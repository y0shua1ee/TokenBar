import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Usage snapshot for custom OpenAI-compatible providers
public struct CustomUsageSnapshot: Codable, Sendable {
    public let displayName: String
    public let balance: Double?
    public let totalUsage: Double?
    public let modelsAvailable: Bool
    public let modelCount: Int
    public let updatedAt: Date

    public init(
        displayName: String,
        balance: Double?,
        totalUsage: Double?,
        modelsAvailable: Bool = false,
        modelCount: Int = 0,
        updatedAt: Date = Date())
    {
        self.displayName = displayName
        self.balance = balance
        self.totalUsage = totalUsage
        self.modelsAvailable = modelsAvailable
        self.modelCount = modelCount
        self.updatedAt = updatedAt
    }
}

extension CustomUsageSnapshot {
    public func toUsageSnapshot() -> UsageSnapshot {
        let primary: RateWindow? = if totalUsage != nil {
            RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil)
        } else {
            nil
        }

        let balanceStr: String = if let bal = balance {
            String(format: "$%.2f", bal)
        } else if let usage = totalUsage {
            "Usage: \(String(format: "$%.2f", usage))"
        } else {
            "Connected (\(modelCount) models)"
        }

        let identity = ProviderIdentitySnapshot(
            providerID: .custom,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "\(displayName): \(balanceStr)")

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            openRouterUsage: nil,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}

/// Response from /v1/models endpoint (OpenAI-compatible)
struct CustomModelsResponse: Decodable {
    let data: [CustomModelEntry]
}

struct CustomModelEntry: Decodable {
    let id: String
}

/// Fetches usage info from custom OpenAI-compatible providers
public enum CustomUsageFetcher: Sendable {
    private static let requestTimeout: TimeInterval = 10

    public static func fetchUsage(
        apiKey: String,
        baseURL: String,
        displayName: String) async throws -> CustomUsageSnapshot
    {
        guard !apiKey.isEmpty else {
            throw CustomProviderError.missingToken
        }

        let sanitizedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        // Try multiple billing endpoints in order
        let billingEndpoints = [
            "/credits",
            "/v1/credits",
            "/dashboard/billing/usage",
            "/usage",
        ]

        var balance: Double?
        var totalUsage: Double?

        for path in billingEndpoints {
            guard let url = URL(string: "\(sanitizedBase)\(path)") else { continue }
            do {
                let (balanceVal, usageVal) = try await Self.fetchBilling(url: url, apiKey: apiKey)
                balance = balanceVal
                totalUsage = usageVal
                break
            } catch {
                continue
            }
        }

        // Try to list models to verify connectivity
        var modelsAvailable = false
        var modelCount = 0
        if let modelsURL = URL(string: "\(sanitizedBase)/models") {
            do {
                modelCount = try await Self.fetchModelCount(url: modelsURL, apiKey: apiKey)
                modelsAvailable = modelCount > 0
            } catch {
                // Also try /v1/models
                if let v1Models = URL(string: "\(sanitizedBase)/v1/models") {
                    do {
                        modelCount = try await Self.fetchModelCount(url: v1Models, apiKey: apiKey)
                        modelsAvailable = modelCount > 0
                    } catch {
                        // Models endpoint unavailable
                    }
                }
            }
        }

        return CustomUsageSnapshot(
            displayName: displayName,
            balance: balance,
            totalUsage: totalUsage,
            modelsAvailable: modelsAvailable,
            modelCount: modelCount)
    }

    private static func fetchBilling(
        url: URL,
        apiKey: String) async throws -> (Double?, Double?)
    {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw CustomProviderError.apiError("HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
        }

        // Try to parse common billing response formats
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // OpenRouter-style: { data: { total_credits, total_usage } }
            if let dataNode = json["data"] as? [String: Any] {
                let credits = (dataNode["total_credits"] as? Double) ?? (dataNode["totalCredits"] as? Double)
                let usage = (dataNode["total_usage"] as? Double) ?? (dataNode["totalUsage"] as? Double)
                if credits != nil || usage != nil {
                    let balance = credits.map { max(0, $0 - (usage ?? 0)) }
                    return (balance, usage)
                }
            }

            // Simple: { balance, usage }
            let bal = json["balance"] as? Double
            let usage = json["usage"] as? Double ?? json["total_usage"] as? Double
            if bal != nil || usage != nil {
                return (bal, usage)
            }
        }

        throw CustomProviderError.apiError("Unrecognized billing response format")
    }

    private static func fetchModelCount(url: URL, apiKey: String) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.requestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw CustomProviderError.apiError("HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
        }

        let decoder = JSONDecoder()
        do {
            let models = try decoder.decode(CustomModelsResponse.self, from: data)
            return models.data.count
        } catch {
            // Try simpler format: { object: "list", data: [...] }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]]
            {
                return dataArray.count
            }
            throw error
        }
    }
}
