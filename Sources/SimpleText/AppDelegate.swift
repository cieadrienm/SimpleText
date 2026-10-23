import AppKit
import SimpleTextCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var documentController: DocumentController!
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
        // Run from the repository there is no bundle icon; the Dock shows the drawn one anyway.
        // Only once launched: set earlier, the Dock tile request hangs an unbundled process.
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") == nil { NSApp.applicationIconImage = AppVersion.icon }
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
            if name.hasPrefix("-") { skip = 1; continue }   // `-key value`, read by UserDefaults
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
}
