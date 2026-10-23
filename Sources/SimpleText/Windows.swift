import AppKit
import SwiftUI
import WebKit

/// A dark auxiliary window holding a SwiftUI view, brought back rather than recreated.
@MainActor
class HostedWindowController {
    private(set) var window: NSWindow?
    private let title: String
    private let size: NSSize
    private let autosaveName: String

    init(title: String, size: NSSize, autosaveName: String) {
        self.title = title
        self.size = size
        self.autosaveName = autosaveName
    }

    func show<Content: View>(_ content: () -> Content, resizable: Bool = false) {
        let hosting = NSHostingView(rootView: content().preferredColorScheme(.dark))
        if let window {
            window.contentView = hosting
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        hosting.frame = NSRect(origin: .zero, size: size)
        var style: NSWindow.StyleMask = [.titled, .closable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: style, backing: .buffered, defer: false)
        window.title = title
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.panel
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = !resizable
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setFrameAutosaveName(autosaveName)
        if window.frame.origin == .zero { window.center() }
        window.animationBehavior = .none
        window.fadeIn()
        self.window = window
    }

    func close() {
        window?.close()
    }
}

/// SimpleText ▸ À propos de SimpleText.
@MainActor
final class AboutWindowController: HostedWindowController {
    static let shared = AboutWindowController(title: "À propos de SimpleText", size: NSSize(width: 580, height: 420), autosaveName: "SimpleTextAbout")

    func show() {
        show({ AboutView(close: { [weak self] in self?.close() }) })
    }
}

/// Aide ▸ Raccourcis clavier (⌘/).
@MainActor
final class ShortcutsWindowController: HostedWindowController {
    static let shared = ShortcutsWindowController(title: "Raccourcis clavier", size: NSSize(width: 820, height: 520), autosaveName: "SimpleTextShortcuts")

    func show() {
        show({ ShortcutsView(close: { [weak self] in self?.close() }) })
    }
}

/// SimpleText ▸ Réglages… (⌘,).
@MainActor
final class SettingsWindowController: HostedWindowController {
    static let shared = SettingsWindowController(title: "Réglages", size: NSSize(width: 460, height: 500), autosaveName: "SimpleTextSettings")

    func show() {
        show({ SettingsView() })
    }
}

/// Aide ▸ Aide SimpleText (⌘?): the bundled HTML guide (`Resources/Help`) in a window of its own.
@MainActor
final class HelpWindowController: NSObject, WKNavigationDelegate {
    static let shared = HelpWindowController()
    private(set) var window: NSWindow?
    private var webView: WKWebView?

    /// In the app bundle, or in the repository when run with `swift run` or `swift test`.
    static var root: URL {
        Bundle.main.url(forResource: "Help", withExtension: nil)
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Help")
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(section: String? = nil) {
        let page = Self.root.appendingPathComponent("index.html")
        var components = URLComponents(url: page, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "v", value: AppVersion.shortLabel)]
        components.fragment = section
        let url = components.url ?? page
        if let window, let webView {
            if let section {
                webView.evaluateJavaScript("location.hash = '\(section)'")
            } else if webView.url == nil {
                webView.loadFileURL(url, allowingReadAccessTo: Self.root)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1040, height: 760))
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground") // no white flash before the dark page paints
        webView.loadFileURL(url, allowingReadAccessTo: Self.root)
        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aide SimpleText"
        window.contentView = webView
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.background
        window.minSize = NSSize(width: 640, height: 420)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SimpleTextHelp")
        if window.frame.origin == .zero { window.center() }
        window.fadeIn()
        self.window = window
        self.webView = webView
    }

    /// Links to the web open in the browser; the guide's own pages stay here.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto" {
            NSWorkspace.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }
}

extension NSWindow {
    /// Brings the window up through a short fade and lift, or at once when motion is reduced.
    func fadeIn() {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduced {
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let target = frame
        alphaValue = 0
        setFrame(target.offsetBy(dx: 0, dy: -8), display: false)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(target, display: true)
        }
    }
}
