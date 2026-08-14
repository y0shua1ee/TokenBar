import CodexBarCore
import Foundation

struct OllamaUIErrorMapper {
    static func userFacingMessage(
        _ raw: String?,
        localize: (String) -> String = L) -> String?
    {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == OllamaUsageError.safariCookieAccessDenied.localizedDescription {
            return localize("ollama_safari_cookie_access_hint")
        }
        if let browserName = self.browserName(
            in: trimmed,
            suffix: " cookie decryption was declined in Keychain. " +
                "Open the provider card and click Refresh (⌘R) to request Keychain access again.")
        {
            return String(format: localize("ollama_browser_cookie_decryption_denied"), browserName)
        }
        let disabledSuffixes = [
            " cookie decryption is disabled in \(TokenBarIdentity.displayName); " +
                "enable Keychain access and refresh.",
            // Accept errors cached by pre-migration builds.
            " cookie decryption is disabled in CodexBar; enable Keychain access and refresh.",
        ]
        for suffix in disabledSuffixes {
            if let browserName = self.browserName(in: trimmed, suffix: suffix) {
                return String(format: localize("ollama_browser_cookie_decryption_disabled"), browserName)
            }
        }
        return trimmed
    }

    private static func browserName(in message: String, suffix: String) -> String? {
        guard message.hasSuffix(suffix) else { return nil }
        let name = String(message.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
