import AppKit
import SimpleTextCore
import UniformTypeIdentifiers

/// One text file. The text lives in `textStorage`, shared with the editor's TextKit 2 stack;
/// encoding and line endings are remembered from the read and restored on write. An RTF file is
/// rich text: AppKit reads and writes it, fonts and colours are the file's own (D22).
final class TextDocument: NSDocument {
    static let rtfType = "public.rtf"

    let textStorage = NSTextStorage()
    private(set) var isRichText = false
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
    override class var readableTypes: [String] { [DocumentController.textType, rtfType, "public.text", "public.source-code", "public.data"] }
    override class var writableTypes: [String] { [DocumentController.textType, rtfType] }
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
        if typeName == Self.rtfType {
            guard let rich = NSAttributedString(rtf: data, documentAttributes: nil) else { throw TextFileError.undecodable }
            isRichText = true
            textStorage.setAttributedString(Self.themed(rich))
            NotificationCenter.default.post(name: Self.textDidReload, object: self)
            return
        }
        if TextFile.isBinary(data) { throw TextFileError.binary }
        let decoded = try TextFile.decode(data, preferred: Preferences.defaultEncoding)
        encoding = decoded.encoding
        hasBOM = decoded.hasBOM
        lineEnding = decoded.lineEnding ?? Preferences.defaultLineEnding
        replaceText(with: decoded.text)
    }

    override func data(ofType typeName: String) throws -> Data {
        if isRichText {
            let all = NSRange(location: 0, length: textStorage.length)
            guard let data = Self.unthemed(textStorage).rtf(from: all, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else {
                throw TextFileError.unencodable(.ascii)
            }
            return data
        }
        return try TextFile.encode(textStorage.string, encoding: encoding, bom: hasBOM, lineEnding: lineEnding)
    }

    /// Keeps the file's own extension; a new document gets `.txt`, or `.rtf` once rich.
    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        if typeName == Self.rtfType { return "rtf" }
        let current = fileURL?.pathExtension ?? ""
        return current.isEmpty ? "txt" : current
    }

    // MARK: Rich text

    /// Text that is black, or has no colour, takes the theme's text colour so it shows on the dark
    /// background; `unthemed` puts it back on write, so the file keeps its black text.
    static func themed(_ rich: NSAttributedString) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: rich)
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            let color = (value as? NSColor)?.usingColorSpace(.sRGB)
            let nearBlack = color.map { $0.redComponent < 0.15 && $0.greenComponent < 0.15 && $0.blueComponent < 0.15 } ?? true
            if nearBlack { text.addAttribute(.foregroundColor, value: Theme.text, range: range) }
        }
        return text
    }

    static func unthemed(_ rich: NSAttributedString) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: rich)
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if (value as? NSColor) == Theme.text { text.removeAttribute(.foregroundColor, range: range) }
        }
        return text
    }

    /// Format › Convertir. To rich text, the text starts clean (no syntax colours, no hidden Markdown
    /// markers end up in a file); to plain text, the formatting goes, and undo brings it back.
    func convert(toRichText rich: Bool) {
        guard rich != isRichText else { return }
        let previous = NSAttributedString(attributedString: textStorage)
        let content = NSAttributedString(string: textStorage.string, attributes: Self.baseAttributes)
        apply(richText: rich, content: content, undoing: previous)
    }

    private func apply(richText rich: Bool, content: NSAttributedString, undoing previous: NSAttributedString) {
        let wasRich = isRichText
        isRichText = rich
        fileType = rich ? Self.rtfType : DocumentController.textType
        textStorage.setAttributedString(content)
        undoManager?.registerUndo(withTarget: self) { $0.apply(richText: wasRich, content: previous, undoing: content) }
        undoManager?.setActionName(rich ? "Convertir en texte enrichi" : "Convertir en texte brut")
        NotificationCenter.default.post(name: Self.textDidReload, object: self)
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
