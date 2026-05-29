import Foundation

public enum BedrockAuthMode: String, Codable, Sendable, CaseIterable {
    case keys
    case profile
}

public enum BedrockSettingsReader {
    public static let accessKeyIDKey = "AWS_ACCESS_KEY_ID"
    public static let secretAccessKeyKey = "AWS_SECRET_ACCESS_KEY"
    public static let sessionTokenKey = "AWS_SESSION_TOKEN"
    public static let regionKeys = ["AWS_REGION", "AWS_DEFAULT_REGION"]
    public static let budgetKey = "TOKENBAR_BEDROCK_BUDGET"
    public static let legacyBudgetKey = "CODEXBAR_BEDROCK_BUDGET"
    public static let apiURLKey = "TOKENBAR_BEDROCK_API_URL"
    public static let legacyAPIURLKey = "CODEXBAR_BEDROCK_API_URL"
    public static let profileKey = "AWS_PROFILE"
    public static let authModeKey = "TOKENBAR_BEDROCK_AUTH_MODE"
    public static let legacyAuthModeKey = "CODEXBAR_BEDROCK_AUTH_MODE"
    public static let defaultRegion = "us-east-1"
    private static let budgetKeys = [Self.budgetKey, Self.legacyBudgetKey]
    private static let apiURLKeys = [Self.apiURLKey, Self.legacyAPIURLKey]
    private static let authModeKeys = [Self.authModeKey, Self.legacyAuthModeKey]

    public static func accessKeyID(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        self.cleaned(environment[self.accessKeyIDKey])
    }

    public static func secretAccessKey(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[self.secretAccessKeyKey])
    }

    public static func sessionToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[self.sessionTokenKey])
    }

    public static func region(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        for key in self.regionKeys {
            if let value = self.cleaned(environment[key]) {
                return value
            }
        }
        return self.defaultRegion
    }

    public static func budget(environment: [String: String] = ProcessInfo.processInfo.environment) -> Double? {
        guard let raw = self.cleanedValue(for: self.budgetKeys, environment: environment),
              let value = Double(raw),
              value > 0
        else {
            return nil
        }
        return value
    }

    static func apiURLOverride(environment: [String: String]) -> URL? {
        guard let raw = self.cleanedValue(for: self.apiURLKeys, environment: environment) else {
            return nil
        }
        return URL(string: raw)
    }

    public static func profile(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[self.profileKey])
    }

    public static func authMode(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> BedrockAuthMode
    {
        if let mode = self.explicitAuthMode(environment: environment) {
            return mode
        }
        if self.profile(environment: environment) != nil,
           !self.hasStaticKeys(environment: environment)
        {
            return .profile
        }
        return .keys
    }

    static func explicitAuthMode(environment: [String: String]) -> BedrockAuthMode? {
        self.cleanedValue(for: self.authModeKeys, environment: environment)
            .flatMap { BedrockAuthMode(rawValue: $0.lowercased()) }
    }

    static func hasStaticKeys(environment: [String: String]) -> Bool {
        self.accessKeyID(environment: environment) != nil &&
            self.secretAccessKey(environment: environment) != nil
    }

    public static func hasCredentials(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool
    {
        switch self.authMode(environment: environment) {
        case .keys:
            self.hasStaticKeys(environment: environment)
        case .profile:
            self.profile(environment: environment) != nil
        }
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value = String(value.dropFirst().dropLast())
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func cleanedValue(for keys: [String], environment: [String: String]) -> String? {
        for key in keys {
            if let value = self.cleaned(environment[key]) {
                return value
            }
        }
        return nil
    }
}
