import Foundation
import Testing
@testable import CodexBar

struct KrillLoginRunnerTests {
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)
    private static let trustedContext = KrillLoginMessageContext(
        isMainFrame: true,
        scheme: "https",
        host: "www.krill-ai.net",
        port: 0)

    @Test
    func `accepts an unexpired JWT only from the trusted main frame origin`() {
        let jwt = Self.jwt(expiry: Self.now.addingTimeInterval(60).timeIntervalSince1970)

        #expect(KrillLoginPolicy.acceptedJWT(jwt, context: Self.trustedContext, now: Self.now) == jwt)
        #expect(KrillLoginPolicy.acceptedJWT(
            jwt,
            context: .init(isMainFrame: true, scheme: "https", host: "www.krill-ai.net", port: 443),
            now: Self.now) == jwt)
        #expect(KrillLoginPolicy.acceptedJWT(
            jwt,
            context: .init(isMainFrame: false, scheme: "https", host: "www.krill-ai.net", port: 443),
            now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT(
            jwt,
            context: .init(isMainFrame: true, scheme: "http", host: "www.krill-ai.net", port: 443),
            now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT(
            jwt,
            context: .init(isMainFrame: true, scheme: "https", host: "krill-ai.net", port: 443),
            now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT(
            jwt,
            context: .init(isMainFrame: true, scheme: "https", host: "www.krill-ai.net", port: 8443),
            now: Self.now) == nil)
    }

    @Test
    func `rejects expired malformed and missing-expiry JWTs`() {
        let expired = Self.jwt(expiry: Self.now.addingTimeInterval(-1).timeIntervalSince1970)
        let missingExpiry = Self.jwt(payload: #"{"sub":"krill-user"}"#)

        #expect(KrillLoginPolicy.acceptedJWT(expired, context: Self.trustedContext, now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT(missingExpiry, context: Self.trustedContext, now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT("not-a-jwt", context: Self.trustedContext, now: Self.now) == nil)
        #expect(KrillLoginPolicy.acceptedJWT(nil, context: Self.trustedContext, now: Self.now) == nil)
    }

    @Test
    func `completion gate accepts exactly one terminal event`() {
        var gate = KrillLoginCompletionGate()
        let firstClaim = gate.claim()
        let secondClaim = gate.claim()

        #expect(firstClaim)
        #expect(gate.isCompleted)
        #expect(!secondClaim)
    }

    private static func jwt(expiry: TimeInterval) -> String {
        self.jwt(payload: #"{"exp":\#(expiry)}"#)
    }

    private static func jwt(payload: String) -> String {
        let header = self.base64URL(Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8))
        let encodedPayload = self.base64URL(Data(payload.utf8))
        return "\(header).\(encodedPayload).signature"
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
