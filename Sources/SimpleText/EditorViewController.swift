import AppKit
import SwiftUI
import SimpleTextCore

/// The editor of one document: the text view and its gutter above the status bar.
final class EditorViewController: NSViewController, NSTextViewDelegate, NSMenuItemValidation {
    let document: TextDocument
    let model = EditorModel()
    private(set) var textView: EditorTextView!
    private(set) var scrollView: NSScrollView!
    private(set) var gutter: LineNumberGutter!
    private var gutterWidth: NSLayoutConstraint!
    private var statusHost: NSHostingView<StatusBar>!
    private(set) var highlighter: SyntaxHighlighter!
    private var lexerName: String?
    private var lineIndexCache: LineIndex?
    private var statisticsTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(document: TextDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        statisticsTimer?.invalidate()
    }

    override func loadView() {
        let root = DropTargetView()
        root.onDrop = { urls in EditorViewController.open(urls) }
        root.wantsLayer = true
        root.layer?.backgroundColor = Theme.background.cgColor

        // TextKit 2, with the stack AppKit builds for the view; the document's storage replaces the
        // view's own so reads, reverts and saves and the editor share one text.
        textView = EditorTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        textView.textContentStorage?.textStorage = document.textStorage
        textView.textContainer?.widthTracksTextView = true
        textView.useRichText(document.isRichText)
        textView.configureAsCodeEditor()
        textView.delegate = self
        textView.languageProvider = { [unowned self] in document.language }
        textView.onOpenFiles = { urls in EditorViewController.open(urls) }

        scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.background
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        gutter = LineNumberGutter()
        gutter.textView = textView
        gutter.lineIndexProvider = { [unowned self] in lineIndex() }
        gutter.onThicknessChange = { [weak self] width in self?.updateGutterWidth(width) }
        gutter.translatesAutoresizingMaskIntoConstraints = false
        // The gutter follows the scroll position.
        scrollView.contentView.postsBoundsChangedNotifications = true

        statusHost = NSHostingView(rootView: StatusBar(model: model, actions: statusActions()))
        statusHost.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(gutter)
        root.addSubview(scrollView)
        root.addSubview(statusHost)
        gutterWidth = gutter.widthAnchor.constraint(equalToConstant: Preferences.showLineNumbers ? gutter.thickness : 0)
        NSLayoutConstraint.activate([
            gutter.topAnchor.constraint(equalTo: root.topAnchor),
            gutter.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            gutter.bottomAnchor.constraint(equalTo: statusHost.topAnchor),
            gutterWidth,
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusHost.topAnchor),
            statusHost.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            statusHost.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusHost.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            statusHost.heightAnchor.constraint(equalToConstant: 26),
        ])
        view = root

        highlighter = SyntaxHighlighter(storage: document.textStorage, baseFont: Preferences.editorFont)
        highlighter.isActive = !document.isRichText
        applyPreferences()
        documentDidReload()
        observe()
    }

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [weak self] _ in
            self?.applyPreferences()
        })
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyPreferences()
        })
        observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            self?.gutter.needsDisplay = true
        })
        observers.append(center.addObserver(forName: TextDocument.textDidReload, object: document, queue: .main) { [weak self] _ in
            self?.documentDidReload()
        })
        observers.append(center.addObserver(forName: TextDocument.languageDidChange, object: document, queue: .main) { [weak self] _ in
            self?.refreshDocumentState()
        })
        observers.append(center.addObserver(forName: TextDocument.encodingDidChange, object: document, queue: .main) { [weak self] _ in
            self?.refreshDocumentState()
        })
    }

    private var lastAppliedFont: NSFont?
    private var lastWordWrap: Bool?

    func applyPreferences() {
        let font = Preferences.editorFont
        if lastAppliedFont != font || textView.tabWidth != Preferences.tabWidth {
            textView.applyFont(font, tabWidth: Preferences.tabWidth)
            highlighter.baseFont = font
            lastAppliedFont = font
            gutter.font = NSFont.monospacedDigitSystemFont(ofSize: max(9, font.pointSize - 2), weight: .regular)
        }
        textView.highlightCurrentLine = Preferences.highlightCurrentLine
        textView.autoIndent = Preferences.autoIndent
        highlighter.hidesMarkup = Preferences.hideMarkdownMarkup
        if textView.indentStyleFromPreferences {
            textView.indentStyle = Preferences.indentStyle
            model.indentLabel = textView.indentStyle.label
        }
        // Defaults change on every window move (frame autosave): only a real change re-tiles the text.
        if lastWordWrap != Preferences.wordWrap {
            lastWordWrap = Preferences.wordWrap
            applyWordWrap(Preferences.wordWrap)
        }
        gutter.invalidate()
        updateGutterWidth(gutter.thickness)
    }

    private func updateGutterWidth(_ width: CGFloat) {
        let target = Preferences.showLineNumbers ? width : 0
        guard gutterWidth.constant != target else { return }
        gutterWidth.constant = target
        gutter.isHidden = target == 0
    }

    private func applyWordWrap(_ wrap: Bool) {
        guard let container = textView.textContainer else { return }
        let huge = CGFloat.greatestFiniteMagnitude
        if wrap {
            container.widthTracksTextView = true
            container.size = NSSize(width: scrollView.contentSize.width, height: huge)
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.frame.size.width = scrollView.contentSize.width
        } else {
            container.widthTracksTextView = false
            container.size = NSSize(width: huge, height: huge)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
        }
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: huge, height: huge)
        scrollView.hasHorizontalScroller = !wrap
    }

    /// After a read, a revert or a reinterpretation: everything about the text is new.
    private func documentDidReload() {
        lineIndexCache = nil
        if textView.isRichText != document.isRichText {
            textView.useRichText(document.isRichText)
            highlighter.isActive = !document.isRichText
            if !document.isRichText { textView.applyFont(Preferences.editorFont, tabWidth: Preferences.tabWidth) }
        }
        textView.indentStyle = IndentStyle.detect(in: document.text, fallback: Preferences.indentStyle)
        textView.indentStyleFromPreferences = false
        textView.needsDisplay = true
        refreshDocumentState()
    }

    func refreshDocumentState() {
        let language = document.language
        if lexerName != language.name {
            lexerName = language.name
            highlighter.lexer = Lexers.lexer(for: language)
        }
        model.isRichText = document.isRichText
        model.languageName = document.isRichText ? "RTF" : document.language.name
        model.encodingName = TextFile.name(of: document.encoding) + (document.hasBOM ? " · BOM" : "")
        model.lineEndingName = document.lineEnding.rawValue
        model.indentLabel = textView.indentStyle.label
        model.highlighted = document.isRichText || highlighter.isEnabled || Lexers.lexer(for: language) == nil
        updateCaretStatus()
        scheduleStatistics()
        gutter.invalidate()
    }

    func lineIndex() -> LineIndex {
        if let cached = lineIndexCache { return cached }
        let index = LineIndex(document.text)
        lineIndexCache = index
        return index
    }

    private func updateCaretStatus() {
        let range = textView.selectedRange()
        let index = lineIndex()
        let (line, column) = index.position(of: range.location)
        model.line = line + 1
        model.column = column + 1
        highlighter.caretLine = line
        model.selectedCharacters = range.length
        model.selectedLines = range.length > 0 ? index.line(containing: NSMaxRange(range) - 1) - line + 1 : 0
    }

    private func scheduleStatistics() {
        statisticsTimer?.invalidate()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            let index = lineIndex()
            model.lines = index.lineCount
            let length = document.textStorage.length
            model.words = length <= TextDocument.highlightLimit ? TextStatistics.measure(document.text).words : nil
        }
    }

    private func statusActions() -> StatusBarActions {
        var actions = StatusBarActions()
        actions.pickLanguage = { [weak self] name in self?.document.languageOverride = Language.named(name) }
        actions.pickEncoding = { [weak self] raw in self?.changeEncoding(String.Encoding(rawValue: raw)) }
        actions.pickLineEnding = { [weak self] raw in
            if let ending = LineEnding(rawValue: raw) { self?.document.setLineEnding(ending) }
        }
        actions.showHelp = { (NSApp.delegate as? AppDelegate)?.showHelp(nil) }
        actions.showShortcuts = { (NSApp.delegate as? AppDelegate)?.showShortcuts(nil) }
        actions.showAbout = { (NSApp.delegate as? AppDelegate)?.showAbout(nil) }
        return actions
    }

    private func changeEncoding(_ encoding: String.Encoding) {
        do {
            try document.setEncoding(encoding)
        } catch {
            if let window = view.window {
                NSApp.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                NSApp.presentError(error)
            }
        }
    }

    static func open(_ urls: [URL]) {
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        }
    }

    // MARK: NSTextViewDelegate

    func undoManager(for view: NSTextView) -> UndoManager? {
        document.undoManager
    }

    func textDidChange(_ notification: Notification) {
        lineIndexCache = nil
        updateCaretStatus()
        scheduleStatistics()
        gutter.invalidate()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateCaretStatus()
        if textView.highlightCurrentLine { textView.needsDisplay = true }
        gutter.needsDisplay = true
    }

    // MARK: Menu actions (Présentation)

    @objc func toggleWordWrap(_ sender: Any?) {
        Preferences.set(!Preferences.wordWrap, for: Preferences.Key.wordWrap)
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        Preferences.set(!Preferences.showLineNumbers, for: Preferences.Key.showLineNumbers)
    }

    @objc func toggleCurrentLineHighlight(_ sender: Any?) {
        Preferences.set(!Preferences.highlightCurrentLine, for: Preferences.Key.highlightCurrentLine)
    }

    @objc func toggleMarkdownMarkup(_ sender: Any?) {
        Preferences.set(!Preferences.hideMarkdownMarkup, for: Preferences.Key.hideMarkdownMarkup)
    }

    @objc func increaseFontSize(_ sender: Any?) {
        Preferences.set(min(48, Preferences.fontSize + 1), for: Preferences.Key.fontSize)
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        Preferences.set(max(8, Preferences.fontSize - 1), for: Preferences.Key.fontSize)
    }

    @objc func resetFontSize(_ sender: Any?) {
        Preferences.set(Preferences.defaults[Preferences.Key.fontSize], for: Preferences.Key.fontSize)
    }

    @objc func setLanguage(_ sender: NSMenuItem) {
        document.languageOverride = (sender.representedObject as? String).flatMap(Language.named)
    }

    @objc func setEncoding(_ sender: NSMenuItem) {
        guard let raw = (sender.representedObject as? NSNumber)?.uintValue else { return }
        changeEncoding(String.Encoding(rawValue: raw))
    }

    @objc func setLineEnding(_ sender: NSMenuItem) {
        guard let ending = (sender.representedObject as? String).flatMap(LineEnding.init(rawValue:)) else { return }
        document.setLineEnding(ending)
    }

    /// Format › Convertir. A saved file is never rewritten in the other format under its own name:
    /// autosave would do it on its own. The conversion goes to a duplicate instead.
    @objc func toggleRichText(_ sender: Any?) {
        let target: TextDocument
        if document.fileURL == nil {
            target = document
        } else {
            guard let copy = try? document.duplicate() as? TextDocument else { return }
            target = copy
        }
        target.convert(toRichText: !document.isRichText)
    }

    @objc func goToLine(_ sender: Any?) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Aller à la ligne"
        alert.informativeText = "Numéro de ligne, de 1 à \(lineIndex().lineCount)."
        alert.addButton(withTitle: "Aller")
        alert.addButton(withTitle: "Annuler")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        field.placeholderString = "\(model.line)"
        field.alignment = .right
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let line = Int(field.stringValue) else { return }
            textView.goTo(line: line, index: lineIndex())
        }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleWordWrap(_:)):
            item.state = Preferences.wordWrap ? .on : .off
        case #selector(toggleLineNumbers(_:)):
            item.state = Preferences.showLineNumbers ? .on : .off
        case #selector(toggleCurrentLineHighlight(_:)):
            item.state = Preferences.highlightCurrentLine ? .on : .off
        case #selector(toggleMarkdownMarkup(_:)):
            item.state = Preferences.hideMarkdownMarkup ? .on : .off
        case #selector(setLanguage(_:)):
            item.state = (item.representedObject as? String) == document.language.name ? .on : .off
            return !document.isRichText
        case #selector(setEncoding(_:)):
            item.state = (item.representedObject as? NSNumber)?.uintValue == document.encoding.rawValue ? .on : .off
            return !document.isRichText
        case #selector(setLineEnding(_:)):
            item.state = (item.representedObject as? String) == document.lineEnding.rawValue ? .on : .off
            return !document.isRichText
        case #selector(toggleRichText(_:)):
            item.title = document.isRichText ? "Convertir en texte brut" : "Convertir en texte enrichi"
            if document.fileURL != nil { item.title += " (copie)" }
        default:
            break
        }
        return true
    }
}

/// The window's content view: files dropped anywhere outside the text open as documents.
final class DropTargetView: NSView {
    var onDrop: ([URL]) -> Void = { _ in }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.fileURLs.isEmpty ? [] : .generic
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.fileURLs
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }
}

extension NSDraggingInfo {
    var fileURLs: [URL] {
        let objects = draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        return (objects as? [URL]) ?? []
    }
}
