import AppKit
import WebKit

/// A real secondary window for `window.open` popups.
///
/// OAuth providers (Google, Apple, Microsoft) open a popup and then talk back to
/// `window.opener`. Loading such a request into the main frame destroys the page
/// that started the flow and strands the user on a blank callback page - so
/// popups get their own window, exactly like a browser tab.
///
/// The popup web view MUST be created with the configuration handed to us by
/// WebKit; that is what links it to its opener.
final class PopupWindowController: NSObject, WKUIDelegate, WKNavigationDelegate {
    let webView: WKWebView
    private let window: NSWindow
    /// Called when the popup closes, so the owner can drop its reference.
    private let onClose: (PopupWindowController) -> Void
    /// Guards against reporting closure twice (`webViewDidClose` + `windowWillClose`).
    private var hasClosed = false

    init(configuration: WKWebViewConfiguration,
         userAgent: String,
         onClose: @escaping (PopupWindowController) -> Void) {
        self.onClose = onClose

        let frame = NSRect(x: 0, y: 0, width: 520, height: 640)
        webView = WKWebView(frame: frame, configuration: configuration)
        webView.customUserAgent = userAgent

        // A titled window so the user can see the provider's domain and close it.
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in"
        window.contentView = webView
        window.center()
        // Above the floating companion panel, otherwise it opens behind it.
        window.level = .modalPanel
        window.isReleasedWhenClosed = false

        super.init()

        webView.uiDelegate = self
        webView.navigationDelegate = self
        window.delegate = self
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        guard !hasClosed else { return }
        hasClosed = true
        window.orderOut(nil)
        onClose(self)
    }

    // MARK: - WKUIDelegate

    /// The page called `window.close()`.
    func webViewDidClose(_ webView: WKWebView) {
        Log.info("popup closed itself")
        dismiss()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        Log.info("popup loaded \(url.host ?? "?")\(url.path)")
        // Keep the title honest about who is asking for credentials.
        if let host = url.host { window.title = "Sign in - \(host)" }
    }
}

// MARK: - NSWindowDelegate

extension PopupWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        dismiss()
    }
}
