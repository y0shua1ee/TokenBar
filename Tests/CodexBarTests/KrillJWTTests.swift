import Foundation
import Testing
@testable import CodexBarCore

struct KrillJWTTests {
    @Test
    func `decodes base64url claims and rejects expired credentials`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = Self.token(expiration: now.timeIntervalSince1970 + 60, subject: "account-a")

        let claims = try KrillJWT.validated(valid, now: now)

        #expect(claims.subject == "account-a")
        #expect(claims.expiration == now.timeIntervalSince1970 + 60)
        #expect(KrillJWT.isExpired(valid, now: now) == false)

        let expired = Self.token(expiration: now.timeIntervalSince1970, subject: nil)
        #expect(throws: KrillJWTError.expired) {
            try KrillJWT.validated(expired, now: now)
        }
        #expect(KrillJWT.isExpired(expired, now: now))
    }

    @Test
    func `malformed JWT fails closed`() {
        #expect(throws: KrillJWTError.malformed) {
            try KrillJWT.validated("not-a-jwt", now: Date(timeIntervalSince1970: 0))
        }
        #expect(KrillJWT.isExpired("not-a-jwt", now: Date(timeIntervalSince1970: 0)))
    }

    @Test
    func `credential fingerprint is deterministic and hides raw credential`() {
        let first = KrillJWT.credentialFingerprint("secret-a")
        let second = KrillJWT.credentialFingerprint("secret-a")
        let other = KrillJWT.credentialFingerprint("secret-b")

        #expect(first == second)
        #expect(first != other)
        #expect(first.count == 64)
        #expect(first.contains("secret") == false)
    }

    @Test
    func `settings reader prefers projected config accepts ambient JWT and strips bearer`() {
        let environment = [
            "CODEXBAR_KRILL_JWT": "  \"Bearer projected.jwt.sig\" ",
            "KRILL_JWT": "ambient.jwt.sig",
        ]
        #expect(KrillSettingsReader.jwt(environment: environment) == "projected.jwt.sig")
        #expect(KrillSettingsReader.jwt(environment: ["KRILL_JWT": " bearer  ambient.jwt.sig "]) == "ambient.jwt.sig")
        #expect(KrillSettingsReader.jwt(environment: ["KRILL_JWT": "Bearer 'ambient.jwt.sig'"]) == "ambient.jwt.sig")
        #expect(KrillSettingsReader.jwt(environment: ["KRILL_JWT": "Bearer"]) == nil)
        #expect(KrillSettingsReader.jwt(environment: ["KRILL_JWT": "  "]) == nil)
    }

    static func token(expiration: TimeInterval, subject: String?) -> String {
        var payload: [String: Any] = ["exp": expiration]
        payload["sub"] = subject
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            preconditionFailure("Krill JWT test payload must be JSON encodable")
        }
        return "header.\(Self.base64URL(data)).signature"
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
