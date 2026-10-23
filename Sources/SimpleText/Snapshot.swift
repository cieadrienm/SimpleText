import AppKit

/// `SimpleText --snapshot out.png [file]`: opens the file (or a sample), renders the window, exits.
/// The only way to look at the app without a screen (DECISIONS.md).
@MainActor
enum Snapshot {
    static let sample = """
    // SimpleText — aperçu
    import Foundation

    struct Clip {
        var name: String
        var gain: Float = 0.5

        func describe() -> String {
            "\\(name) à \\(gain) dB"   // interpolation
        }
    }
    """

    /// What the window server shows (title bar included); the view cache when the window is off screen.
    static func render(_ window: NSWindow) -> Data? {
        let windowID = CGWindowID(window.windowNumber)
        if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution]),
           image.width > 1 {
            return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        }
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    static func run(output: String, input: String?) {
        let controller = NSDocumentController.shared
        let environment = ProcessInfo.processInfo.environment
        let delay = Double(environment["SIMPLETEXT_SNAPSHOT_DELAY"] ?? "") ?? 0.6
        let finish: (NSDocument?) -> Void = { document in
            // SIMPLETEXT_SNAPSHOT_WINDOW=about|shortcuts|settings|help photographs that window instead.
            let delegate = NSApp.delegate as? AppDelegate
            var auxiliary: NSWindow?
            switch environment["SIMPLETEXT_SNAPSHOT_WINDOW"] {
            case "about": delegate?.showAbout(nil); auxiliary = AboutWindowController.shared.window
            case "shortcuts": delegate?.showShortcuts(nil); auxiliary = ShortcutsWindowController.shared.window
            case "settings": delegate?.showSettings(nil); auxiliary = SettingsWindowController.shared.window
            case "help": delegate?.showHelp(nil); auxiliary = HelpWindowController.shared.window
            case "open":
                // The real ⌘O path; the panel is remote, so only the hook is reported.
                controller.openDocument(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    print("open panel configured by beginOpenPanel: \(DocumentController.panelConfigured)")
                    exit(DocumentController.panelConfigured ? 0 : 5)
                }
                return
            default: break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // SIMPLETEXT_SNAPSHOT_MENU=Fichier opens that menu for an instant (the app takes the
                // focus for it) and lists its items instead: menus cannot be photographed.
                if let title = environment["SIMPLETEXT_SNAPSHOT_MENU"] {
                    let menu = NSApp.mainMenu?.items.first { $0.title == title }?.submenu
                    if let menu, let view = NSApp.windows.first?.contentView {
                        NSApp.activate(ignoringOtherApps: true)
                        let close = Timer(timeInterval: 0.4, repeats: false) { _ in menu.cancelTrackingWithoutAnimation() }
                        RunLoop.main.add(close, forMode: .common)
                        menu.popUp(positioning: nil, at: .zero, in: view)
                    }
                    for item in menu?.items ?? [] {
                        print(item.isSeparatorItem ? "—" : item.title + (item.submenu.map { " ▸ \($0.items.count)" } ?? ""))
                    }
                    exit(0)
                }
                guard let window = auxiliary ?? document?.windowControllers.first?.window ?? NSApp.windows.first,
                      let view = window.contentView else {
                    fputs("snapshot error: no window\n", stderr)
                    exit(2)
                }
                (window.contentViewController as? EditorViewController)?.highlighter.flush()
                view.layoutSubtreeIfNeeded()
                view.displayIfNeeded()
                guard let png = render(window) else { exit(3) }
                let url = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try png.write(to: url, options: .atomic)
                    print("snapshot written to \(url.path) (\(png.count) bytes)")
                    exit(0)
                } catch {
                    fputs("snapshot error: \(error)\n", stderr)
                    exit(1)
                }
            }
        }
        if let input, !input.isEmpty {
            let url = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
            controller.openDocument(withContentsOf: url, display: true) { document, _, error in
                if let error {
                    fputs("snapshot error: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
                (document as? TextDocument)?.windowControllers.first?.window?.setContentSize(NSSize(width: 1180, height: 740))
                finish(document)
            }
        } else {
            let document = try? controller.openUntitledDocumentAndDisplay(true) as? TextDocument
            document?.replaceText(with: sample)
            document?.windowControllers.first?.window?.setContentSize(NSSize(width: 1180, height: 740))
            finish(document)
        }
    }
}
