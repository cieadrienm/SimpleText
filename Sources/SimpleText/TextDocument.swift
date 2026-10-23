import AppKit
import SimpleTextCore
import UniformTypeIdentifiers

/// One text file. The text lives in `textStorage`, shared with the editor's TextKit 2 stack;
/// encoding and line endings are remembered from the read and restored on write.
final class TextDocument: NSDocument {
    let textStorage = NSTextStorage()
    private(set) var encoding: String.Encoding = Preferences.defaultEncoding
    private(set) var hasBOM = false
    private(set) var lineEnding: LineEnding = Preferences.defaultLineEnding
    /// Set from the status bar; nil means the file name decides.
    var languageOverride: Language? {
        didSet { NotificationCenter.default.post(name: Self.languageDidChange, object: self) }
    }

    static let languageDidChange = Notification.Name("net.cieadrienm.simpletext.languageDidChange")
    static let encodingDidChange = Notification.Name("net.cieadrienm.simpletext.encodingDidChange")
    /// Posted after the whole text was replaced by a read, a revert or a reinterpretation.
    static let textDidReload = Notification.Name("net.cieadrienm.simpletext.textDidReload")

    /// Above this size the highlighter stays off: a log of hundreds of megabytes still opens and scrolls.
    static let highlightLimit = 4_000_000

    var language: Language {
        languageOverride ?? Language.forFile(named: fileURL?.lastPathComponent ?? "")
    }

    var text: String { textStorage.string }

    override class var autosavesInPlace: Bool { true }
    override class var readableTypes: [String] { [DocumentController.textType, "public.text", "public.source-code", "public.data"] }
    override class var writableTypes: [String] { [DocumentController.textType] }
    override class func isNativeType(_ type: String) -> Bool { true }

    override init() {
        super.init()
        textStorage.setAttributedString(NSAttributedString(string: "", attributes: Self.baseAttributes))
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: Preferences.editorFont, .foregroundColor: Theme.text]
    }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        if TextFile.isBinary(data) { throw TextFileError.binary }
        let decoded = try TextFile.decode(data, preferred: Preferences.defaultEncoding)
        encoding = decoded.encoding
        hasBOM = decoded.hasBOM
        lineEnding = decoded.lineEnding ?? Preferences.defaultLineEnding
        replaceText(with: decoded.text)
    }

    override func data(ofType typeName: String) throws -> Data {
        try TextFile.encode(textStorage.string, encoding: encoding, bom: hasBOM, lineEnding: lineEnding)
    }

    /// Keeps the file's own extension; a new document gets `.txt`.
    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        let current = fileURL?.pathExtension ?? ""
        return current.isEmpty ? "txt" : current
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = []
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.showsHiddenFiles = Preferences.showHiddenFiles
        return true
    }

    /// Replaces the whole text outside of undo: reads, reverts and reinterpretations are not edits.
    func replaceText(with text: String) {
        textStorage.setAttributedString(NSAttributedString(string: text, attributes: Self.baseAttributes))
        NotificationCenter.default.post(name: Self.textDidReload, object: self)
    }

    /// Reads the file again in `encoding` when the document is clean; otherwise only the next save changes.
    func setEncoding(_ newEncoding: String.Encoding) throws {
        guard newEncoding != encoding else { return }
        if let fileURL, !isDocumentEdited, let data = try? Data(contentsOf: fileURL) {
            let body = TextFile.byteOrderMark(for: newEncoding).map { mark in
                data.starts(with: mark) ? data.dropFirst(mark.count) : data
            } ?? data
            guard let text = String(data: body, encoding: newEncoding) else { throw TextFileError.unencodable(newEncoding) }
            encoding = newEncoding
            hasBOM = body.count != data.count
            lineEnding = LineEnding.detect(in: text) ?? lineEnding
            replaceText(with: LineEnding.normalize(text))
        } else {
            guard textStorage.string.data(using: newEncoding, allowLossyConversion: false) != nil else {
                throw TextFileError.unencodable(newEncoding)
            }
            encoding = newEncoding
            hasBOM = false
            updateChangeCount(.changeDone)
        }
        NotificationCenter.default.post(name: Self.encodingDidChange, object: self)
    }

    func setLineEnding(_ newEnding: LineEnding) {
        guard newEnding != lineEnding else { return }
        lineEnding = newEnding
        updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Self.encodingDidChange, object: self)
    }
}
