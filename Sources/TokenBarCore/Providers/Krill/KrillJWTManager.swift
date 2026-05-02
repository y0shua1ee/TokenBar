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
    /// Throws KrillAPIError.missingJWT if the user closes the window without logging in.
    public func loginViaWebView() async throws -> String {
        let runner = KrillLoginRunner(jwtManager: self)
        WebKitTeardown.retain(runner)

        let jwt = try await runner.run()
        storeJWT(jwt)
        return jwt
    }
}

/// Self-contained login runner.
/// JWT extraction uses WKUserScript + WKScriptMessageHandler — a polling script
/// injected at document start that watches localStorage for 'krill_jwt' and
/// posts it via webkit.messageHandlers. This avoids the timing issues of
/// WKNavigationDelegate.didFinish (where evaluateJavaScript may run before
/// the SPA has written the JWT to localStorage, especially with .nonPersistent()
/// data stores).
@MainActor
private final class KrillLoginRunner: NSObject {
    private let jwtManager: KrillJWTManager
    private var webView: WKWebView?
    private var window: NSWindow?
    private var continuation: CheckedContinuation<String, any Error>?
    private var hasCompleted = false

    private static let messageHandlerName = "tokenbarKrillJWT"
    private static let loginURL = URL(string: "https://www.krill-ai.com/login")!

    init(jwtManager: KrillJWTManager) {
        self.jwtManager = jwtManager
        super.init()
    }

    func run() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Switch to regular activation policy BEFORE creating the window.
            // LSUIElement apps (menu-bar-only, no Dock icon) cannot reliably
            // receive keyboard input in WebView text fields even with floating
            // level + FocusableWebView + RunLoop activation workarounds.
            // Temporarily switching to .regular gives the process full foreground
            // status so the window server routes keystrokes to the WebView.
            // We restore .accessory in complete() after the window is torn down.
            NSApp.setActivationPolicy(.regular)
            self.setupWindow()
        }
    }

    private func setupWindow() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()

        // ── Message handler: receives JWT from injected JS poll script ──
        config.userContentController.add(self, name: Self.messageHandlerName)

        // ── User script: polls localStorage for krill_jwt every 500ms ──
        let pollScript = WKUserScript(
            source: """
            (function() {
                var checked = false;
                function poll() {
                    if (checked) return;
                    var jwt = localStorage.getItem('krill_jwt');
                    if (jwt) {
                        checked = true;
                        window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage(jwt);
                        return;
                    }
                    setTimeout(poll, 500);
                }
                // Start polling after a short delay to let the SPA initialize
                setTimeout(poll, 300);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(pollScript)

        // FocusableWebView subclass overrides acceptsFirstResponder / becomeFirstResponder
        // to force keyboard routing into the WebView.
        let webView = FocusableWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "Krill Login"
        // PREVENT the crash: macOS default isReleasedWhenClosed=true auto-deallocs
        // the window, but we still hold references — boom.
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.center()
        window.delegate = self
        self.window = window

        webView.load(URLRequest(url: Self.loginURL))

        // Activate and show the window. With .regular activation policy already
        // set in run(), the process IS the foreground app and keyboard events
        // route normally.
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(webView)
    }

    private func complete(with result: Result<String, any Error>) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        self.scheduleCleanup()

        // Restore accessory activation policy asynchronously after the window
        // has been torn down.  The delay gives WebKitTeardown time to fully
        // release the WebView and window before the policy change, avoiding
        // the use-after-free crash.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            NSApp.setActivationPolicy(.accessory)
        }

        continuation.resume(with: result)
    }

    private func scheduleCleanup() {
        WebKitTeardown.scheduleCleanup(owner: self, window: self.window, webView: self.webView)
    }
}

// MARK: - WKScriptMessageHandler (JWT extraction)

extension KrillLoginRunner: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage)
    {
        guard !hasCompleted,
              message.name == Self.messageHandlerName,
              let jwt = message.body as? String,
              !jwt.isEmpty,
              !jwtManager.isJWTExpired(jwt)
        else {
            return
        }

        hasCompleted = true
        complete(with: .success(jwt))
    }
}

// MARK: - WKNavigationDelegate (keyboard focus only)

extension KrillLoginRunner: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard !self.hasCompleted else { return }

            // Re-assert keyboard focus on the WebView after every navigation.
            // SPA route changes can shuffle the responder chain.
            if let window = self.window {
                window.makeFirstResponder(webView)
            }
            let focusJS = """
            (function() {\
              var el = document.querySelector(\
            'input[type="text"], input[type="email"], input[type="password"]');\
              if (el) el.focus();\
            })();
            """
            _ = try? await webView.evaluateJavaScript(focusJS)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error)
    {
        Task { @MainActor in
            self.complete(with: .failure(error))
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error)
    {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }
            self.complete(with: .failure(error))
        }
    }
}

// MARK: - NSWindowDelegate

extension KrillLoginRunner: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard !self.hasCompleted else { return }
            self.complete(with: .failure(KrillAPIError.missingJWT))
        }
    }
}

/// WKWebView subclass that unconditionally accepts first-responder status.
/// In LSUIElement apps, the default WKWebView may refuse to become first
/// responder because the app process isn't considered "active" by the
/// window server. Overriding these forces keyboard routing into the WebView.
private final class FocusableWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

#endif
