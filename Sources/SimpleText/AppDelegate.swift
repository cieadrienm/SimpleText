import AppKit
import SimpleTextCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private(set) var documentController: DocumentController!
    private var snapshotRequest: (output: String, input: String?)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.register()
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        // The first document controller made becomes `NSDocumentController.shared`.
        documentController = DocumentController()
        NSApp.mainMenu = MainMenu.build(delegate: self)
        NSWindow.allowsAutomaticWindowTabbing = true

        let args = Array(CommandLine.arguments.dropFirst())
        if let index = args.firstIndex(of: "--snapshot") {
            let output = index + 1 < args.count ? args[index + 1] : "/tmp/simpletext-snapshot.png"
            let input = index + 2 < args.count ? args[index + 2] : nil
            snapshotRequest = (output, input)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let snapshotRequest {
            Snapshot.run(output: snapshotRequest.output, input: snapshotRequest.input)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        snapshotRequest == nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Paths on the command line (`swift run SimpleText notes.md`); the `--snapshot` arguments are not files.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var skip = 0
        for name in filenames {
            if skip > 0 { skip -= 1; continue }
            if name == "--snapshot" { skip = 2; continue }
            if name.hasPrefix("--") { continue }
            let url = URL(fileURLWithPath: name)
            documentController.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        }
        sender.reply(toOpenOrPrint: .success)
    }

    // MARK: Menu actions

    @objc func showAbout(_ sender: Any?) {
        AboutWindowController.shared.show()
    }

    @objc func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc func showHelp(_ sender: Any?) {
        HelpWindowController.shared.show()
    }

    @objc func showShortcuts(_ sender: Any?) {
        ShortcutsWindowController.shared.show()
    }

    @objc func openRecentDocument(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        documentController.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }

    @objc func clearRecentDocuments(_ sender: Any?) {
        documentController.clearRecentDocuments(sender)
    }

    /// Fichier ▸ Ouvrir l’élément récent, rebuilt from the document controller each time it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = documentController.recentDocumentURLs
        if urls.isEmpty {
            let empty = NSMenuItem(title: "Aucun élément récent", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for url in urls {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentDocument(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.toolTip = url.path
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Effacer le menu", action: #selector(clearRecentDocuments(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }
}
