import AppKit
import SimpleTextCore

/// Opens any text file, whatever its extension, and lets the open panel show hidden files.
final class DocumentController: NSDocumentController {
    static let textType = "public.plain-text"

    override var defaultType: String? { Self.textType }

    override func documentClass(forType typeName: String) -> AnyClass? {
        TextDocument.self
    }

    /// A file is text when its first bytes hold no NUL, extension or not; binary files are refused here,
    /// before any document is made for them. RTF is told by its extension or its `{\rtf` header.
    override func typeForContents(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: 8192) ?? Data()
        if TextFile.isBinary(head) { throw TextFileError.binary }
        if url.pathExtension.lowercased() == "rtf" || head.starts(with: Array("{\\rtf".utf8)) { return TextDocument.rtfType }
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

    /// Set once AppKit has handed a panel to `configurePanel`; `--snapshot` with
    /// SIMPLETEXT_SNAPSHOT_WINDOW=open reports it, since a remote panel cannot be photographed.
    private(set) static var panelConfigured = false

    /// Any file, hidden ones on request; the checkbox in the panel changes it live and remembers it.
    func configurePanel(_ panel: NSOpenPanel) {
        Self.panelConfigured = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = true
        panel.allowedContentTypes = []
        panel.showsHiddenFiles = Preferences.showHiddenFiles
        panel.message = "Tout fichier texte peut être ouvert, quelle que soit son extension."

        panel.accessoryView = HiddenFilesAccessory(panel: panel)
        panel.isAccessoryViewDisclosed = true
    }
}

/// The checkbox under the open panel. It knows its panel without retaining it: the panel owns this view,
/// and a strong or weak Swift reference to a panel crashes once AppKit disposes of it.
final class HiddenFilesAccessory: NSView {
    unowned(unsafe) private let panel: NSSavePanel
    let checkbox: NSButton

    init(panel: NSSavePanel) {
        self.panel = panel
        checkbox = NSButton(checkboxWithTitle: "Afficher les fichiers masqués", target: nil, action: nil)
        checkbox.state = Preferences.showHiddenFiles ? .on : .off
        checkbox.sizeToFit()
        super.init(frame: NSRect(x: 0, y: 0, width: checkbox.frame.width + 40, height: 36))
        checkbox.target = self
        checkbox.action = #selector(toggle(_:))
        checkbox.frame.origin = NSPoint(x: 20, y: (36 - checkbox.frame.height) / 2)
        addSubview(checkbox)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows or hides the dot files at once, and remembers the choice.
    @objc func toggle(_ sender: NSButton) {
        let shown = sender.state == .on
        Preferences.showHiddenFiles = shown
        panel.showsHiddenFiles = shown
    }
}
