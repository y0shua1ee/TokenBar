import Foundation
#if os(macOS)
import Security
#endif

public protocol KrillLegacyJWTStoring: Sendable {
    func loadJWT() throws -> String?
    func deleteJWT() throws
}

public enum KrillLegacyJWTStoreError: LocalizedError, Sendable {
    case interactionNotAllowed
    case keychainStatus(Int32)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .interactionNotAllowed:
            "Krill's legacy sign-in cannot be migrated without Keychain access."
        case let .keychainStatus(status):
            "Krill legacy Keychain error: \(status)"
        case .invalidData:
            "Krill's legacy Keychain item contains invalid data."
        }
    }
}

/// Reads the JWT written by TokenBar releases that predated provider-config credentials.
///
/// The query is intentionally non-interactive. A locked or ACL-protected item is left in place so
/// a later foreground launch can retry without presenting a background Keychain prompt.
public struct KeychainKrillLegacyJWTStore: KrillLegacyJWTStoring {
    public static let service = "com.tokenbar.krill-jwt"

    public init() {}

    public func loadJWT() throws -> String? {
        #if os(macOS)
        guard !KeychainAccessGate.isDisabled else {
            throw KrillLegacyJWTStoreError.interactionNotAllowed
        }

        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        KeychainNoUIQuery.apply(to: &query)

        let status = KeychainSecurity.copyMatching(query as CFDictionary, &result)
        switch status {
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed:
            throw KrillLegacyJWTStoreError.interactionNotAllowed
        case errSecSuccess:
            break
        default:
            throw KrillLegacyJWTStoreError.keychainStatus(status)
        }

        guard let data = result as? Data,
              let value = String(bytes: data, encoding: .utf8)
        else {
            throw KrillLegacyJWTStoreError.invalidData
        }
        let jwt = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return jwt.isEmpty ? nil : jwt
        #else
        return nil
        #endif
    }

    public func deleteJWT() throws {
        #if os(macOS)
        guard !KeychainAccessGate.isDisabled else {
            throw KrillLegacyJWTStoreError.interactionNotAllowed
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
        ]
        KeychainNoUIQuery.apply(to: &query)

        let status = KeychainSecurity.delete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        case errSecInteractionNotAllowed:
            throw KrillLegacyJWTStoreError.interactionNotAllowed
        default:
            throw KrillLegacyJWTStoreError.keychainStatus(status)
        }
        #endif
    }
}
