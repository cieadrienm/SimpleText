import AppKit
import SimpleTextCore

/// Opens any text file, whatever its extension, and lets the open panel show hidden files.
final class DocumentController: NSDocumentController {
    static let textType = "public.plain-text"

    private weak var currentPanel: NSOpenPanel?

    override var defaultType: String? { Self.textType }

    override func documentClass(forType typeName: String) -> AnyClass? {
        TextDocument.self
    }

    /// A file is text when its first bytes hold no NUL, extension or not; binary files are refused here,
    /// before any document is made for them.
    override func typeForContents(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: 8192) ?? Data()
        if TextFile.isBinary(head) { throw TextFileError.binary }
        return Self.textType
    }

    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        configurePanel(openPanel)
        super.beginOpenPanel(openPanel, forTypes: nil, completionHandler: completionHandler)
    }

    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        configurePanel(openPanel)
        return super.runModalOpenPanel(openPanel, forTypes: nil)
    }

    /// Any file, hidden ones on request; the checkbox in the panel changes it live and remembers it.
    func configurePanel(_ panel: NSOpenPanel) {
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = true
        panel.allowedContentTypes = []
        panel.showsHiddenFiles = Preferences.showHiddenFiles
        panel.message = "Tout fichier texte peut être ouvert, quelle que soit son extension."

        let checkbox = NSButton(checkboxWithTitle: "Afficher les fichiers masqués", target: self, action: #selector(toggleHiddenFiles(_:)))
        checkbox.state = Preferences.showHiddenFiles ? .on : .off
        checkbox.sizeToFit()
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: checkbox.frame.width + 40, height: 36))
        checkbox.frame.origin = NSPoint(x: 20, y: (36 - checkbox.frame.height) / 2)
        accessory.addSubview(checkbox)
        panel.accessoryView = accessory
        panel.isAccessoryViewDisclosed = true
        currentPanel = panel
    }

    var hiddenFilesCheckbox: NSButton? {
        currentPanel?.accessoryView?.subviews.compactMap { $0 as? NSButton }.first
    }

    @objc func toggleHiddenFiles(_ sender: NSButton) {
        let shown = sender.state == .on
        Preferences.showHiddenFiles = shown
        currentPanel?.showsHiddenFiles = shown
    }
}
