import AppKit
import SimpleTextCore

/// NSTextView set up as a code editor: every "smart" text feature off, monospaced font,
/// indentation and line commands, the current line drawn behind the text.
final class EditorTextView: NSTextView {
    var languageProvider: () -> Language = { .plainText }
    var onOpenFiles: ([URL]) -> Void = { _ in }
    var indentStyle = IndentStyle(usesTabs: false, width: 4)
    /// Until a document is read, the indent style is the preference; afterwards it is what the file uses.
    var indentStyleFromPreferences = true
    var autoIndent = true
    private(set) var tabWidth = 4
    var highlightCurrentLine = true {
        didSet { needsDisplay = true }
    }

    /// Rich text for an RTF document: the file's fonts and colours, the font panel, no code helpers.
    /// Set before `configureAsCodeEditor`, which would otherwise stamp the editor font over the text.
    func useRichText(_ rich: Bool) {
        isRichText = rich
        usesFontPanel = rich
    }

    func configureAsCodeEditor() {
        importsGraphics = false
        usesRuler = false
        usesInspectorBar = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        allowsDocumentBackgroundColorChange = false
        allowsUndo = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isVerticallyResizable = true
        textContainerInset = NSSize(width: 8, height: 12)
        drawsBackground = true
        backgroundColor = Theme.background
        if !isRichText { textColor = Theme.text }   // the setter recolours the whole text
        insertionPointColor = Theme.caret
        selectedTextAttributes = [.backgroundColor: Theme.selection]
        applyFont(Preferences.editorFont, tabWidth: Preferences.tabWidth)
    }

    /// True when no AppKit substitution can change what the user types (checked by the tests).
    var smartFeaturesDisabled: Bool {
        !isRichText && !isAutomaticQuoteSubstitutionEnabled && !isAutomaticDashSubstitutionEnabled
            && !isAutomaticTextReplacementEnabled && !isAutomaticSpellingCorrectionEnabled
            && !isAutomaticDataDetectionEnabled && !isAutomaticLinkDetectionEnabled
            && !isAutomaticTextCompletionEnabled && !isContinuousSpellCheckingEnabled
            && !isGrammarCheckingEnabled && !smartInsertDeleteEnabled
    }

    /// One font and one tab width for the whole text; the highlighter keeps its colours and puts its
    /// Markdown fonts back afterwards.
    func applyFont(_ font: NSFont, tabWidth: Int) {
        self.tabWidth = tabWidth
        guard !isRichText else { return }
        self.font = font
        let style = NSMutableParagraphStyle()
        style.tabStops = []
        style.defaultTabInterval = (" " as NSString).size(withAttributes: [.font: font]).width * CGFloat(tabWidth)
        defaultParagraphStyle = style
        typingAttributes = [.font: font, .foregroundColor: Theme.text, .paragraphStyle: style]
        if let storage = textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.addAttributes([.font: font, .paragraphStyle: style], range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
    }

    // MARK: Lines

    private var nsString: NSString { string as NSString }

    private func lineRange(for range: NSRange) -> NSRange {
        nsString.lineRange(for: range)
    }

    private func text(in range: NSRange) -> String {
        nsString.substring(with: range)
    }

    /// Replaces through the undo-aware path, then puts the selection where the caller wants it.
    private func replace(_ range: NSRange, with text: String, selection: NSRange? = nil) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
        if let selection {
            let end = nsString.length
            let location = min(selection.location, end)
            setSelectedRange(NSRange(location: location, length: min(selection.length, end - location)))
        }
    }

    func goTo(line: Int, index: LineIndex) {
        let target = max(1, min(line, index.lineCount)) - 1
        let offset = index.start(ofLine: target)
        setSelectedRange(NSRange(location: offset, length: 0))
        scrollRangeToVisible(selectedRange())
        centerSelectionInVisibleArea(nil)
    }

    override func insertNewline(_ sender: Any?) {
        guard autoIndent else { return super.insertNewline(sender) }
        let selection = selectedRange()
        let lineStart = lineRange(for: NSRange(location: selection.location, length: 0)).location
        let before = text(in: NSRange(location: lineStart, length: selection.location - lineStart))
        let indent = String(before.prefix { $0 == " " || $0 == "\t" })
        let lastSignificant = before.trimmingCharacters(in: .whitespaces).last
        let opens = lastSignificant.map { "{([".contains($0) } ?? false
        let extra = opens ? indentStyle.unit : ""
        let after = NSMaxRange(selection)
        let next: Character? = after < nsString.length ? Character(UnicodeScalar(nsString.character(at: after)).map(String.init) ?? " ") : nil
        let closes = opens && (next.map { "})]".contains($0) } ?? false)
        var insertion = "\n" + indent + extra
        if closes { insertion += "\n" + indent }
        let caret = selection.location + 1 + (indent as NSString).length + (extra as NSString).length
        replace(selection, with: insertion, selection: NSRange(location: caret, length: 0))
    }

    override func insertTab(_ sender: Any?) {
        guard !isRichText else { return super.insertTab(sender) }
        let selection = selectedRange()
        if selection.length > 0, text(in: selection).contains("\n") {
            indentSelection(sender)
            return
        }
        if indentStyle.usesTabs {
            insertText("\t", replacementRange: selection)
            return
        }
        let lineStart = lineRange(for: NSRange(location: selection.location, length: 0)).location
        let column = selection.location - lineStart
        let count = indentStyle.width - column % indentStyle.width
        insertText(String(repeating: " ", count: count), replacementRange: selection)
    }

    override func insertBacktab(_ sender: Any?) {
        guard !isRichText else { return super.insertBacktab(sender) }
        outdentSelection(sender)
    }

    // MARK: Format menu (rich text only)

    /// In plain text NSTextView would apply the font or colour panel to the whole text.
    override func changeFont(_ sender: Any?) {
        if isRichText { super.changeFont(sender) }
    }

    override func changeColor(_ sender: Any?) {
        if isRichText { super.changeColor(sender) }
    }

    override func changeAttributes(_ sender: Any?) {
        if isRichText { super.changeAttributes(sender) }
    }

    /// The item's tag is the trait mask `addFontTrait:` reads: bold 2, italic 1.
    @objc func toggleFontTrait(_ sender: Any?) {
        NSFontManager.shared.addFontTrait(sender)
    }

    @objc func showFontPanel(_ sender: Any?) {
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    @objc func showColorPanel(_ sender: Any?) {
        NSApp.orderFrontColorPanel(sender)
    }

    private static let richTextActions: Set<Selector> = [
        #selector(toggleFontTrait(_:)), #selector(showFontPanel(_:)), #selector(showColorPanel(_:)),
        #selector(NSText.underline(_:)), #selector(NSText.alignLeft(_:)), #selector(NSText.alignCenter(_:)),
        #selector(NSText.alignRight(_:)), #selector(NSTextView.alignJustified(_:)),
    ]

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if !isRichText, let action = item.action, Self.richTextActions.contains(action) { return false }
        return super.validateUserInterfaceItem(item)
    }

    /// Applies `transform` to every selected line, keeping a caret on its line and a selection on its lines.
    private func transformSelectedLines(_ transform: (String) -> String) {
        let selection = selectedRange()
        let range = lineRange(for: selection)
        let block = text(in: range)
        let endsWithNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if endsWithNewline { lines.removeLast() }
        let result = lines.map(transform).joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        let newLength = (result as NSString).length
        let newSelection: NSRange
        if selection.length == 0 {
            let firstDelta = (lines.first.map { (transform($0) as NSString).length - ($0 as NSString).length }) ?? 0
            newSelection = NSRange(location: max(range.location, selection.location + firstDelta), length: 0)
        } else {
            newSelection = NSRange(location: range.location, length: newLength)
        }
        replace(range, with: result, selection: newSelection)
    }

    @objc func indentSelection(_ sender: Any?) {
        let unit = indentStyle.unit
        transformSelectedLines { $0.isEmpty ? $0 : unit + $0 }
    }

    @objc func outdentSelection(_ sender: Any?) {
        let width = indentStyle.width
        transformSelectedLines { line in
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            let spaces = line.prefix(width).prefix { $0 == " " }.count
            return String(line.dropFirst(spaces))
        }
    }

    @objc func toggleComment(_ sender: Any?) {
        let language = languageProvider()
        if let prefix = language.lineComment {
            toggleLineComment(prefix)
        } else if let block = language.blockComment {
            toggleBlockComment(block)
        }
    }

    private func toggleLineComment(_ prefix: String) {
        let range = lineRange(for: selectedRange())
        let lines = text(in: range).components(separatedBy: "\n")
        let meaningful = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allCommented = !meaningful.isEmpty && meaningful.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
        let column = meaningful.map { $0.prefix { $0 == " " || $0 == "\t" }.count }.min() ?? 0
        transformSelectedLines { line in
            if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
            if allCommented {
                guard let start = line.range(of: prefix) else { return line }
                var rest = line[start.upperBound...]
                if rest.hasPrefix(" ") { rest = rest.dropFirst() }
                return String(line[..<start.lowerBound]) + rest
            }
            let index = line.index(line.startIndex, offsetBy: min(column, line.count))
            return String(line[..<index]) + prefix + " " + String(line[index...])
        }
    }

    private func toggleBlockComment(_ block: Language.BlockComment) {
        let selection = selectedRange()
        let selected = text(in: selection)
        if selected.hasPrefix(block.open), selected.hasSuffix(block.close), selected.count >= block.open.count + block.close.count {
            let inner = String(selected.dropFirst(block.open.count).dropLast(block.close.count))
            replace(selection, with: inner, selection: NSRange(location: selection.location, length: (inner as NSString).length))
        } else {
            let wrapped = block.open + selected + block.close
            replace(selection, with: wrapped, selection: NSRange(location: selection.location, length: (wrapped as NSString).length))
        }
    }

    @objc func duplicateLine(_ sender: Any?) {
        let selection = selectedRange()
        let range = lineRange(for: selection)
        var block = text(in: range)
        if block.hasSuffix("\n") {
            let shift = (block as NSString).length
            replace(NSRange(location: range.location, length: 0), with: block,
                    selection: NSRange(location: selection.location + shift, length: selection.length))
        } else {
            block = "\n" + block
            let shift = (block as NSString).length
            replace(NSRange(location: NSMaxRange(range), length: 0), with: block,
                    selection: NSRange(location: selection.location + shift, length: selection.length))
        }
    }

    @objc func deleteLine(_ sender: Any?) {
        var range = lineRange(for: selectedRange())
        // The last line has no newline of its own: take the one before it.
        if !text(in: range).hasSuffix("\n"), range.location > 0 {
            range = NSRange(location: range.location - 1, length: range.length + 1)
        }
        replace(range, with: "", selection: NSRange(location: range.location, length: 0))
    }

    @objc func moveLineUp(_ sender: Any?) {
        let selection = selectedRange()
        let range = lineRange(for: selection)
        guard range.location > 0 else { return }
        let previous = lineRange(for: NSRange(location: range.location - 1, length: 0))
        var block = text(in: range)
        var other = text(in: previous)
        if !block.hasSuffix("\n") {
            block += "\n"
            other = String(other.dropLast())
        }
        let union = NSUnionRange(previous, range)
        let location = union.location + (selection.location - range.location)
        replace(union, with: block + other, selection: NSRange(location: location, length: selection.length))
    }

    @objc func moveLineDown(_ sender: Any?) {
        let selection = selectedRange()
        let range = lineRange(for: selection)
        guard NSMaxRange(range) < nsString.length else { return }
        let next = lineRange(for: NSRange(location: NSMaxRange(range), length: 0))
        var other = text(in: next)
        var block = text(in: range)
        if !other.hasSuffix("\n") {
            other += "\n"
            block = String(block.dropLast())
        }
        let union = NSUnionRange(range, next)
        let location = union.location + (other as NSString).length + (selection.location - range.location)
        replace(union, with: other + block, selection: NSRange(location: location, length: selection.length))
    }

    // MARK: Drawing

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard highlightCurrentLine, selectedRange().length == 0, let lineRect = currentLineRect() else { return }
        let row = NSRect(x: 0, y: lineRect.minY, width: bounds.width, height: lineRect.height)
        if row.intersects(rect) {
            Theme.currentLine.setFill()
            row.fill()
        }
    }

    /// The rectangle of the visual line holding the caret, in the view's coordinates.
    func currentLineRect() -> NSRect? {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager else { return nil }
        let caret = selectedRange().location
        guard let location = contentManager.location(contentManager.documentRange.location, offsetBy: caret) else { return nil }
        var found: NSTextLayoutFragment?
        layoutManager.enumerateTextLayoutFragments(from: location, options: [.ensuresLayout]) { fragment in
            found = fragment
            return false
        }
        guard let fragment = found else { return nil }
        let offsetInFragment = contentManager.offset(from: fragment.rangeInElement.location, to: location)
        var rect = fragment.layoutFragmentFrame
        for line in fragment.textLineFragments {
            let lineRange = line.characterRange
            let last = line === fragment.textLineFragments.last
            if NSLocationInRange(offsetInFragment, lineRange) || (last && offsetInFragment == NSMaxRange(lineRange)) {
                rect = NSRect(x: 0, y: fragment.layoutFragmentFrame.minY + line.typographicBounds.minY,
                              width: bounds.width, height: line.typographicBounds.height)
                break
            }
        }
        return rect.offsetBy(dx: 0, dy: textContainerOrigin.y)
    }

    // MARK: Drops

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.fileURLs.isEmpty ? super.draggingEntered(sender) : .generic
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.fileURLs.isEmpty ? super.draggingUpdated(sender) : .generic
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.fileURLs
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        onOpenFiles(urls)
        return true
    }
}
