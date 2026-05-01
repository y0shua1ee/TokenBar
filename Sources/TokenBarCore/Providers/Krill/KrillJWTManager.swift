#if os(macOS)
import Foundation
import WebKit

/// Manages Krill JWT lifecycle: storage in Keychain, expiration checking, and WebView-based login.
@MainActor
public final class KrillJWTManager: @unchecked Sendable {
    public static let shared = KrillJWTManager()
    private static let keychainService = "com.tokenbar.krill-jwt"

    private init() {}

    // MARK: - Keychain

    public func getStoredJWT() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let jwt = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        if isJWTExpired(jwt) {
            deleteJWT()
            return nil
        }

        return jwt
    }

    public func storeJWT(_ jwt: String) {
        deleteJWT()
        guard let data = jwt.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteJWT() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - JWT Expiry

    public func isJWTExpired(_ jwt: String) -> Bool {
        let parts = jwt.components(separatedBy: ".")
        guard parts.count >= 2 else { return true }

        let payloadBase64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padded = payloadBase64 + String(repeating: "=", count: (4 - payloadBase64.count % 4) % 4)

        guard let payloadData = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval
        else {
            return true
        }

        let expiryDate = Date(timeIntervalSince1970: exp)
        return Date() >= expiryDate
    }

    // MARK: - WebView Login

    /// Opens a WebView window for Krill login. Returns the JWT from localStorage on success.
    public func loginViaWebView() async throws -> String {
        NSApp.activate(ignoringOtherApps: true)

        // Force-fresh browser state
        let store = WKWebsiteDataStore.nonPersistent()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = store

        // Inject a script that auto-focuses the first input field on every page load.
        // This works around the keyboard-focus bug in menu-bar-only (.accessory) apps
        // where WKWebView's internal DOM doesn't get first-responder status.
        let focusScript = WKUserScript(
            source: """
            (function() {
                // Focus the email input as soon as it appears
                var obs = new MutationObserver(function() {
                    var input = document.querySelector('input[type="email"], input[type="text"]');
                    if (input) {
                        input.focus();
                        obs.disconnect();
                    }
                });
                obs.observe(document.documentElement, {childList: true, subtree: true});
                // Also try immediately in case the DOM is already ready
                setTimeout(function() {
                    var input = document.querySelector('input[type="email"], input[type="text"]');
                    if (input) input.focus();
                }, 500);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(focusScript)

        let webView = WKWebView(frame: .zero, configuration: config)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "Krill Login"
        window.center()
        window.level = .floating
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)

        guard let loginURL = URL(string: "https://www.krill-ai.com/login") else {
            throw KrillAPIError.missingJWT
        }
        webView.load(URLRequest(url: loginURL))

        let jwt = try await waitForJWT(webView: webView, window: window)
        storeJWT(jwt)
        window.close()

        return jwt
    }

    /// Poll the WebView until JWT appears in localStorage (user logged in successfully).
    private func waitForJWT(webView: WKWebView, window: NSWindow) async throws -> String {
        let maxAttempts = 120
        let pollInterval: TimeInterval = 1.0

        for attempt in 0 ..< maxAttempts {
            if !window.isVisible {
                throw KrillAPIError.missingJWT
            }

            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }

            let js = "localStorage.getItem('krill_jwt')"
            do {
                let result = try await webView.evaluateJavaScript(js)
                if let jwt = result as? String, !jwt.isEmpty, !isJWTExpired(jwt) {
                    return jwt
                }
            } catch {
                continue
            }

            if let currentURL = webView.url?.absoluteString,
               currentURL.contains("/app"),
               attempt > 5
            {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let retryResult = try? await webView.evaluateJavaScript(js)
                if let jwt = retryResult as? String, !jwt.isEmpty, !isJWTExpired(jwt) {
                    return jwt
                }
            }
        }

        throw KrillAPIError.missingJWT
    }
}

#endif
