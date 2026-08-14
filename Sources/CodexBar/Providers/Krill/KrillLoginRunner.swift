import AppKit
import CodexBarCore
import Foundation
import WebKit

struct KrillLoginMessageContext: Equatable, Sendable {
    let isMainFrame: Bool
    let scheme: String
    let host: String
    let port: Int
}

enum KrillLoginPolicy {
    static let messageHandlerName = "tokenbarKrillJWT"

    static func acceptedJWT(
        _ value: String?,
        context: KrillLoginMessageContext,
        now: Date = Date()) -> String?
    {
        // WKSecurityOrigin exposes a normalized default HTTPS port as 0; accept an explicit 443 as well.
        let usesDefaultHTTPSPort = context.port == 0 || context.port == 443
        guard context.isMainFrame,
              context.scheme.lowercased() == "https",
              context.host.lowercased() == "www.krill-ai.net",
              usesDefaultHTTPSPort,
              let jwt = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jwt.isEmpty,
              self.isUnexpiredJWT(jwt, now: now)
        else {
            return nil
        }
        return jwt
    }

    static func isUnexpiredJWT(_ jwt: String, now: Date = Date()) -> Bool {
        (try? KrillJWT.validated(jwt, now: now)) != nil
    }
}

struct KrillLoginCompletionGate {
    private(set) var isCompleted = false

    mutating func claim() -> Bool {
        guard !self.isCompleted else { return false }
        self.isCompleted = true
        return true
    }
}

enum KrillLoginError: LocalizedError {
    case cancelled
    case navigationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Krill login was cancelled."
        case let .navigationFailed(message):
            message
        }
    }
}

/// Opens an ephemeral Krill login window and returns the JWT published by Krill's own origin.
/// The runner is created only for an explicit user-initiated login action.
@MainActor
final class KrillLoginRunner: NSObject {
    private var webView: WKWebView?
    private var window: NSWindow?
    private var continuation: CheckedContinuation<String, any Error>?
    private var completionGate = KrillLoginCompletionGate()

    func run() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                guard !Task.isCancelled else {
                    self.complete(with: .failure(CancellationError()))
                    return
                }
                self.presentLoginWindow()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.complete(with: .failure(CancellationError()))
            }
        }
    }

    private func presentLoginWindow() {
        DockIconController.shared.promote()

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: KrillLoginPolicy.messageHandlerName)
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.jwtPollingScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: .zero)
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Krill Login"
        window.isReleasedWhenClosed = false
        window.contentView = container
        window.center()
        window.delegate = self

        self.webView = webView
        self.window = window
        WebKitTeardown.retain(self)

        webView.load(URLRequest(url: KrillAPIClient.loginURL))
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)
        DockIconController.shared.registerPresentedWindow(window)
    }

    private func complete(with result: Result<String, any Error>) {
        guard self.completionGate.claim() else { return }

        let continuation = self.continuation
        self.continuation = nil

        let window = self.window
        let webView = self.webView
        if let window {
            DockIconController.shared.unregisterPresentedWindow(window)
        }
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: KrillLoginPolicy.messageHandlerName)
        webView?.configuration.userContentController.removeAllUserScripts()
        webView?.navigationDelegate = nil
        window?.delegate = nil
        self.webView = nil
        self.window = nil

        WebKitTeardown.scheduleCleanup(
            owner: self,
            window: window,
            webView: webView,
            closeWindow: { window?.close() })
        continuation?.resume(with: result)
    }

    private static let jwtPollingScript = """
    (() => {
      let completed = false;
      const poll = () => {
        if (completed) return;
        const jwt = window.localStorage.getItem('krill_jwt');
        if (jwt) {
          completed = true;
          window.webkit.messageHandlers.\(KrillLoginPolicy.messageHandlerName).postMessage(jwt);
          return;
        }
        window.setTimeout(poll, 500);
      };
      window.setTimeout(poll, 250);
    })();
    """
}

extension KrillLoginRunner: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage)
    {
        guard message.name == KrillLoginPolicy.messageHandlerName else { return }
        let origin = message.frameInfo.securityOrigin
        let context = KrillLoginMessageContext(
            isMainFrame: message.frameInfo.isMainFrame,
            scheme: origin.protocol,
            host: origin.host,
            port: origin.port)
        guard let jwt = KrillLoginPolicy.acceptedJWT(message.body as? String, context: context) else { return }
        self.complete(with: .success(jwt))
    }
}

extension KrillLoginRunner: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.window?.makeFirstResponder(webView)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error)
    {
        self.complete(with: .failure(KrillLoginError.navigationFailed(error.localizedDescription)))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error)
    {
        let nsError = error as NSError
        guard nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled else { return }
        self.complete(with: .failure(KrillLoginError.navigationFailed(error.localizedDescription)))
    }
}

extension KrillLoginRunner: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.complete(with: .failure(KrillLoginError.cancelled))
    }
}
