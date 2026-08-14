import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public struct KrillJWTClaims: Decodable, Equatable, Sendable {
    public let expiration: TimeInterval
    public let subject: String?
    public let email: String?

    private enum CodingKeys: String, CodingKey {
        case expiration = "exp"
        case subject = "sub"
        case email
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(TimeInterval.self, forKey: .expiration) {
            self.expiration = value
        } else if let raw = try? container.decode(String.self, forKey: .expiration),
                  let value = TimeInterval(raw)
        {
            self.expiration = value
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .expiration,
                in: container,
                debugDescription: "Krill JWT exp claim is missing or invalid")
        }
        self.subject = try container.decodeIfPresent(String.self, forKey: .subject)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
    }
}

public enum KrillJWT {
    /// Parses JWT claims without verifying the signature. Krill's server remains the signature authority.
    public static func claims(in token: String) throws -> KrillJWTClaims {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { throw KrillJWTError.malformed }
        guard let payload = self.decodeBase64URL(String(segments[1])) else {
            throw KrillJWTError.malformed
        }
        do {
            let claims = try JSONDecoder().decode(KrillJWTClaims.self, from: payload)
            guard claims.expiration.isFinite, claims.expiration > 0 else {
                throw KrillJWTError.malformed
            }
            return claims
        } catch let error as KrillJWTError {
            throw error
        } catch {
            throw KrillJWTError.malformed
        }
    }

    @discardableResult
    public static func validated(
        _ token: String,
        now: Date = Date(),
        expirationLeeway: TimeInterval = 0) throws -> KrillJWTClaims
    {
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw KrillJWTError.missing }
        let claims = try self.claims(in: cleaned)
        let leeway = max(0, expirationLeeway)
        guard claims.expiration > now.timeIntervalSince1970 + leeway else {
            throw KrillJWTError.expired
        }
        return claims
    }

    public static func isExpired(_ token: String, now: Date = Date()) -> Bool {
        guard let claims = try? self.claims(in: token) else { return true }
        return claims.expiration <= now.timeIntervalSince1970
    }

    /// Returns a one-way account-scope discriminator. The raw credential must never be persisted in cost history.
    public static func credentialFingerprint(_ token: String) -> String {
        let material = "\(TokenBarIdentity.persistenceNamespace).krill.credential.v1\0\(token)"
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingCount = (4 - normalized.utf8.count % 4) % 4
        return Data(base64Encoded: normalized + String(repeating: "=", count: paddingCount))
    }
}

public enum KrillJWTError: LocalizedError, Equatable, Sendable {
    case missing
    case malformed
    case expired

    public var errorDescription: String? {
        switch self {
        case .missing:
            "Krill login is required."
        case .malformed:
            "The stored Krill login credential is invalid. Please sign in again."
        case .expired:
            "The stored Krill login has expired. Please sign in again."
        }
    }
}
