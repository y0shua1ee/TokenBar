import Foundation

public enum KrillSettingsReader {
    /// Provider config projects its `apiKey` field here. The value is a Krill web-login JWT, not an API key.
    public static let projectedJWTEnvironmentKey = "CODEXBAR_KRILL_JWT"
    public static let ambientJWTEnvironmentKey = "KRILL_JWT"
    public static let jwtEnvironmentKeys = [Self.projectedJWTEnvironmentKey, Self.ambientJWTEnvironmentKey]

    public static func jwt(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        for key in self.jwtEnvironmentKeys {
            if let value = self.cleaned(environment[key]) {
                return value
            }
        }
        return nil
    }

    public static func validatedJWT(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()) throws -> String
    {
        guard let token = self.jwt(environment: environment) else {
            throw KrillJWTError.missing
        }
        try KrillJWT.validated(token, now: now)
        return token
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        value = self.strippingMatchingQuotes(value)

        let bearer = "Bearer"
        if value.caseInsensitiveCompare(bearer) == .orderedSame {
            return nil
        }
        if value.count > bearer.count {
            let boundary = value.index(value.startIndex, offsetBy: bearer.count)
            if value[..<boundary].caseInsensitiveCompare(bearer) == .orderedSame,
               value[boundary].isWhitespace
            {
                value = String(value[boundary...]).trimmingCharacters(in: .whitespacesAndNewlines)
                value = self.strippingMatchingQuotes(value)
            }
        }
        return value.isEmpty ? nil : value
    }

    private static func strippingMatchingQuotes(_ value: String) -> String {
        guard value.count >= 2,
              value.hasPrefix("\"") && value.hasSuffix("\"") ||
              value.hasPrefix("'") && value.hasSuffix("'")
        else { return value }
        return String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
