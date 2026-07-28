#if os(macOS)
import AppKit
import Foundation
import WebKit

enum DeepSeekPlatformTokenStore {
    static let keychainService = "com.tokenbar.deepseek-platform-token"

    static func hasStoredTokenNoUI() -> Bool {
        guard !KeychainAccessGate.isDisabled else { return false }
        if case .allowed = KeychainAccessPreflight.checkGenericPassword(
            service: self.keychainService,
            account: nil)
        {
            return true
        }
        return false
    }

    static func loadNoUI() -> String? {
        guard !KeychainAccessGate.isDisabled else { return nil }
        let query = self.makeLoadQuery()

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func store(_ token: String) {
        guard !KeychainAccessGate.isDisabled else { return }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        let itemQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(itemQuery as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }

        var addQuery = itemQuery
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func delete() {
        guard !KeychainAccessGate.isDisabled else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func makeLoadQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        KeychainNoUIQuery.apply(to: &query)
        return query
    }

    #if DEBUG
    static func makeLoadQueryForTesting() -> [String: Any] {
        self.makeLoadQuery()
    }
    #endif
}

@MainActor
public final class DeepSeekPlatformTokenManager: @unchecked Sendable {
    public static let shared = DeepSeekPlatformTokenManager()

    private init() {}

    public func getStoredToken() -> String? {
        DeepSeekPlatformTokenStore.loadNoUI()
    }

    public func hasStoredToken() -> Bool {
        DeepSeekPlatformTokenStore.hasStoredTokenNoUI()
    }

    public func storeToken(_ token: String) {
        DeepSeekPlatformTokenStore.store(token)
    }

    public func deleteToken() {
        DeepSeekPlatformTokenStore.delete()
    }

    public func loginViaWebView() async throws -> String {
        let runner = DeepSeekPlatformLoginRunner(tokenManager: self)
        WebKitTeardown.retain(runner)

        let token = try await runner.run()
        self.storeToken(token)
        return token
    }
}

@MainActor
private final class DeepSeekPlatformLoginRunner: NSObject {
    private let tokenManager: DeepSeekPlatformTokenManager
    private var webView: WKWebView?
    private var window: NSWindow?
    private var continuation: CheckedContinuation<String, any Error>?
    private var hasCompleted = false

    private static let messageHandlerName = "tokenbarDeepSeekPlatformToken"
    private static let loginURL = URL(string: "https://platform.deepseek.com/usage")!

    init(tokenManager: DeepSeekPlatformTokenManager) {
        self.tokenManager = tokenManager
        super.init()
    }

    func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            NSApp.setActivationPolicy(.regular)
            self.setupWindow()
        }
    }

    private func setupWindow() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: Self.messageHandlerName)
        config.userContentController.addUserScript(Self.tokenPollingScript())

        let webView = DeepSeekFocusableWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "DeepSeek Dashboard Login"
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.center()
        window.delegate = self
        self.window = window

        webView.load(URLRequest(url: Self.loginURL))

        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(webView)
    }

    private static func tokenPollingScript() -> WKUserScript {
        WKUserScript(
            source: """
            (function() {
                var checked = false;

                function unwrapToken(raw) {
                    var candidate = raw;
                    for (var i = 0; i < 4; i++) {
                        if (candidate === null || candidate === undefined) return null;
                        if (typeof candidate !== 'string') {
                            if (candidate && typeof candidate === 'object' && 'value' in candidate) {
                                candidate = candidate.value;
                                continue;
                            }
                            return null;
                        }
                        var trimmed = candidate.trim();
                        if (!trimmed) return null;
                        var first = trimmed.charAt(0);
                        if (first !== '{' && first !== '"' && first !== '[') return trimmed;
                        try {
                            var parsed = JSON.parse(trimmed);
                            if (typeof parsed === 'string') {
                                candidate = parsed;
                                continue;
                            }
                            if (parsed && typeof parsed === 'object' && 'value' in parsed) {
                                candidate = parsed.value;
                                continue;
                            }
                            return null;
                        } catch (e) {
                            return trimmed;
                        }
                    }
                    return null;
                }

                function poll() {
                    if (checked) return;
                    var token = unwrapToken(localStorage.getItem('userToken'));
                    if (token) {
                        checked = true;
                        window.webkit.messageHandlers.\(self.messageHandlerName).postMessage(token);
                        return;
                    }
                    setTimeout(poll, 500);
                }

                setTimeout(poll, 300);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true)
    }

    private func complete(with result: Result<String, any Error>) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        self.scheduleCleanup()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            NSApp.setActivationPolicy(.accessory)
        }

        continuation.resume(with: result)
    }

    private func scheduleCleanup() {
        WebKitTeardown.scheduleCleanup(owner: self, window: self.window, webView: self.webView)
    }
}

extension DeepSeekPlatformLoginRunner: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage)
    {
        guard !self.hasCompleted,
              message.name == Self.messageHandlerName,
              let token = message.body as? String
        else {
            return
        }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.hasCompleted = true
        self.complete(with: .success(trimmed))
    }
}

extension DeepSeekPlatformLoginRunner: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard !self.hasCompleted else { return }
            self.window?.makeFirstResponder(webView)
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

extension DeepSeekPlatformLoginRunner: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard !self.hasCompleted else { return }
            self.complete(with: .failure(DeepSeekDashboardUsageError.missingPlatformToken))
        }
    }
}

private final class DeepSeekFocusableWebView: WKWebView {
    override var acceptsFirstResponder: Bool {
        true
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        true
    }
}
#endif
