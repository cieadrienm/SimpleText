import AppKit
import SimpleTextCore

/// Colours the document's text storage from a lexer, one line at a time. Each line's end state is
/// kept, so after an edit only the changed lines and those whose state differs are lexed again.
/// Attribute changes go straight to the storage, outside the undo manager: they never dirty the document.
/// A lexer with `usesFonts` (Markdown) also gets fonts, underlines and backgrounds: the source stays
/// as typed, formatted in place.
final class SyntaxHighlighter {
    private let storage: NSTextStorage
    /// UTF-16 offset where each line starts; the first is always 0.
    private(set) var lineStarts: [Int] = [0]
    /// The lexer state after each line.
    private var endStates: [LexState] = [.initial]
    private var dirtyFirst: Int?
    private var dirtyLast = 0
    private var relexScheduled = false
    private var observer: NSObjectProtocol?

    var lexer: (any Lexer)? {
        didSet {
            if oldValue?.usesFonts == true || lexer?.usesFonts == true { resetStyles(NSRange(location: 0, length: storage.length)) }
            highlightAll()
        }
    }

    /// The font the text view gives every character; the Markdown variants derive from it.
    var baseFont: NSFont {
        didSet {
            guard baseFont != oldValue else { return }
            fonts = MarkupFonts(base: baseFont)
            if lexer?.usesFonts == true { highlightAll() }
        }
    }
    private var fonts: MarkupFonts
    private var usesFonts: Bool { lexer?.usesFonts == true }

    /// Markdown markers vanish on every line but the caret's, where they come back faded to be edited.
    var hidesMarkup = false {
        didSet { if hidesMarkup != oldValue, usesFonts { highlightAll() } }
    }
    var caretLine = 0 {
        didSet {
            guard hidesMarkup, usesFonts, caretLine != oldValue else { return }
            restyle(oldValue)
            restyle(caretLine)
        }
    }

    /// Lexes one line again now, merged with whatever edit is still pending.
    private func restyle(_ line: Int) {
        guard line < lineStarts.count else { return }
        dirtyFirst = min(dirtyFirst ?? line, line)
        dirtyLast = max(dirtyLast, line)
        relexDirtyLines()
    }

    /// Lexing stops above this size; the text stays in the base colour.
    var limit = TextDocument.highlightLimit

    /// False for rich text: the colours and fonts are the document's own, nothing is written.
    var isActive = true {
        didSet { if isActive != oldValue, isActive { highlightAll() } }
    }

    var isEnabled: Bool { isActive && lexer != nil && storage.length <= limit }

    init(storage: NSTextStorage, baseFont: NSFont) {
        self.storage = storage
        self.baseFont = baseFont
        fonts = MarkupFonts(base: baseFont)
        rebuildIndex()
        observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification, object: storage, queue: nil
        ) { [weak self] _ in
            self?.storageDidChange()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: Line index

    private func rebuildIndex() {
        let text = storage.string as NSString
        let length = text.length
        var starts = [0]
        var buffer = [UInt16](repeating: 0, count: min(length, 65536))
        var offset = 0
        while offset < length {
            let count = min(buffer.count, length - offset)
            text.getCharacters(&buffer, range: NSRange(location: offset, length: count))
            for i in 0..<count where buffer[i] == 10 { starts.append(offset + i + 1) }
            offset += count
        }
        lineStarts = starts
        endStates = [LexState](repeating: .initial, count: starts.count)
    }

    func line(containing offset: Int) -> Int {
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }

    /// Keeps the index in step with an edit: starts inside the replaced text go, starts of the new
    /// text come, every later start shifts. Nothing is lexed here; that waits for the run loop.
    private func storageDidChange() {
        guard storage.editedMask.contains(.editedCharacters) else { return }
        let edited = storage.editedRange
        let delta = storage.changeInLength
        let oldRange = NSRange(location: edited.location, length: edited.length - delta)
        let firstLine = line(containing: oldRange.location)

        // Old starts whose newline lay inside the replaced range.
        var removeFrom = firstLine + 1
        while removeFrom < lineStarts.count, lineStarts[removeFrom] - 1 < oldRange.location { removeFrom += 1 }
        var removeTo = removeFrom
        while removeTo < lineStarts.count, lineStarts[removeTo] - 1 < NSMaxRange(oldRange) { removeTo += 1 }

        var newStarts: [Int] = []
        if edited.length > 0 {
            var buffer = [UInt16](repeating: 0, count: edited.length)
            (storage.string as NSString).getCharacters(&buffer, range: edited)
            for (i, unit) in buffer.enumerated() where unit == 10 { newStarts.append(edited.location + i + 1) }
        }
        for k in removeTo..<lineStarts.count { lineStarts[k] += delta }
        lineStarts.replaceSubrange(removeFrom..<removeTo, with: newStarts)
        endStates.replaceSubrange(removeFrom..<removeTo, with: [LexState](repeating: .initial, count: newStarts.count))

        let lastLine = firstLine + newStarts.count
        dirtyFirst = min(dirtyFirst ?? firstLine, firstLine)
        dirtyLast = max(dirtyLast, lastLine)
        scheduleRelex()
    }

    private func scheduleRelex() {
        guard !relexScheduled, isEnabled else { return }
        relexScheduled = true
        // The run loop, not the main dispatch queue: the latter is not drained by `RunLoop.run` in tests.
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            guard let self else { return }
            relexScheduled = false
            relexDirtyLines()
        }
    }

    // MARK: Lexing

    func highlightAll() {
        guard isActive else { return }
        rebuildIndex()
        dirtyFirst = 0
        dirtyLast = lineStarts.count - 1
        if isEnabled {
            relexDirtyLines()
            return
        }
        dirtyFirst = nil
        dirtyLast = 0
        if storage.length > 0 {
            let all = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.foregroundColor, range: all)
            storage.addAttribute(.foregroundColor, value: Theme.text, range: all)
            if usesFonts { resetStyles(all) }
            storage.endEditing()
        }
    }

    /// Lines coloured per run loop turn: a large file colours from the top while it stays responsive.
    private let batchLines = 4000

    /// Lexes from the first dirty line and stops after the last one as soon as a line ends in the
    /// state it ended in before; later lines then cannot change.
    private func relexDirtyLines() {
        guard let first = dirtyFirst else { return }
        guard let lexer, isEnabled else {
            dirtyFirst = nil
            dirtyLast = 0
            return
        }
        let last = min(dirtyLast, lineStarts.count - 1)
        dirtyFirst = nil
        dirtyLast = 0
        let batchEnd = first + batchLines
        let text = storage.string as NSString
        let length = text.length
        var state = first == 0 ? LexState.initial : endStates[first - 1]
        var buffer = [UInt16]()
        storage.beginEditing()
        var i = first
        while i < lineStarts.count {
            let start = lineStarts[i]
            let end = i + 1 < lineStarts.count ? lineStarts[i + 1] - 1 : length
            let count = max(0, end - start)
            if buffer.count < count { buffer = [UInt16](repeating: 0, count: count) }
            if count > 0 { text.getCharacters(&buffer, range: NSRange(location: start, length: count)) }
            let line = buffer[0..<count]
            let tokens = lexer.tokenize(line, state: &state)
            apply(tokens, line: line, lineStart: start, hidingMarkers: hidesMarkup && i != caretLine)
            let previous = endStates[i]
            endStates[i] = state
            i += 1
            if i > last, previous == state { break }
            if i >= batchEnd, i < lineStarts.count {
                dirtyFirst = i
                dirtyLast = max(last, i)
                scheduleRelex()
                break
            }
        }
        storage.endEditing()
    }

    /// Colours everything still pending, now; the snapshot and the tests use it.
    func flush() {
        while dirtyFirst != nil { relexDirtyLines() }
    }

    private func apply(_ tokens: [Token], line: Line, lineStart: Int, hidingMarkers: Bool) {
        let lineLength = line.count
        guard lineLength > 0 else { return }
        let lineRange = NSRange(location: lineStart, length: lineLength)
        storage.addAttribute(.foregroundColor, value: Theme.text, range: lineRange)
        if usesFonts { resetStyles(lineRange) }
        for token in tokens where token.kind != .plain {
            let range = NSRange(location: lineStart + token.range.lowerBound, length: token.range.count)
            storage.addAttribute(.foregroundColor, value: Theme.color(for: token.kind), range: range)
            if usesFonts { style(token, line: line, range: range, hidingMarkers: hidingMarkers) }
        }
    }

    /// One font, no underline, strike or background: what every line starts from before its tokens.
    private func resetStyles(_ range: NSRange) {
        guard range.length > 0 else { return }
        storage.addAttribute(.font, value: fonts.base, range: range)
        for key in [NSAttributedString.Key.underlineStyle, .strikethroughStyle, .backgroundColor, .obliqueness] {
            storage.removeAttribute(key, range: range)
        }
    }

    /// Markdown shown formatted, markup kept: bigger bold headings, bold, italic, struck, underlined
    /// links, inline code on a tile, and the markers themselves faded so the words stand out, or
    /// hidden: a 0.1 pt clear font takes no room, and the text itself is untouched.
    private func style(_ token: Token, line: Line, range: NSRange, hidingMarkers: Bool) {
        func mark(_ range: NSRange) {
            guard range.length > 0 else { return }
            if hidingMarkers {
                storage.addAttributes([.font: fonts.hidden, .foregroundColor: NSColor.clear], range: range)
            } else {
                storage.addAttribute(.foregroundColor, value: Theme.textFaint, range: range)
            }
        }
        func fade(_ leading: Int, _ trailing: Int = 0) {
            let leading = min(leading, range.length), trailing = min(trailing, range.length - leading)
            mark(NSRange(location: range.location, length: leading))
            mark(NSRange(location: NSMaxRange(range) - trailing, length: trailing))
        }
        func italic(_ range: NSRange) {
            storage.addAttribute(.font, value: fonts.italic, range: range)
            if fonts.italicIsSynthesised { storage.addAttribute(.obliqueness, value: 0.2, range: range) }
        }
        switch token.kind {
        case .heading:
            var i = line.startIndex
            while i < line.endIndex, line[i] == 32 || line[i] == 9 { i += 1 }
            let hashes = i
            while i < line.endIndex, line[i] == 35 { i += 1 }
            let level = min(max(i - hashes, 1), fonts.headings.count)
            storage.addAttribute(.font, value: fonts.headings[level - 1], range: range)
            let spaceAfter = hidingMarkers && i < line.endIndex && line[i] == 32 ? 1 : 0
            mark(NSRange(location: range.location + hashes - line.startIndex, length: i - hashes + spaceAfter))
        case .strong:
            storage.addAttribute(.font, value: fonts.bold, range: range)
            fade(2, 2)
        case .emphasis:
            italic(range)
            fade(1, 1)
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            fade(2, 2)
        case .codeSpan where token.range.count < line.count:
            var ticks = 0
            while token.range.lowerBound + ticks < line.endIndex, line[token.range.lowerBound + ticks] == 96 { ticks += 1 }
            storage.addAttribute(.backgroundColor, value: Theme.laneAlt, range: range)
            fade(ticks, ticks)
        case .link:
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            fade(line[token.range.lowerBound] == 33 ? 2 : 1, 1)
        case .meta where hidingMarkers && line[token.range.lowerBound] == 40:
            mark(range)   // the (url) after a link
        case .quote:
            italic(range)
            var i = line.startIndex
            while i < line.endIndex, line[i] == 32 || line[i] == 9 { i += 1 }
            let spaceAfter = hidingMarkers && i + 1 < line.endIndex && line[i + 1] == 32 ? 1 : 0
            mark(NSRange(location: range.location + i - line.startIndex, length: 1 + spaceAfter))
        case .listMarker:
            storage.addAttribute(.font, value: fonts.bold, range: range)
        default:
            break
        }
    }
}

/// The editor font's variants used by formatted Markdown, derived once per base font.
struct MarkupFonts {
    let base: NSFont
    let bold: NSFont
    let italic: NSFont
    /// What hidden markers wear: no width to speak of, drawn clear.
    let hidden: NSFont
    /// Index = heading level − 1; the first three grow, the rest are only bold.
    let headings: [NSFont]
    /// The family has no italic face: the text view slants the regular one instead.
    let italicIsSynthesised: Bool

    init(base: NSFont) {
        let boldFont = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(.bold), size: base.pointSize) ?? base
        let italicFont = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(.italic), size: base.pointSize) ?? base
        self.base = base
        bold = boldFont
        italic = italicFont
        hidden = NSFont(descriptor: base.fontDescriptor, size: 0.1) ?? base
        italicIsSynthesised = !italicFont.fontDescriptor.symbolicTraits.contains(.italic)
        headings = [1.4, 1.25, 1.1, 1, 1, 1].map { NSFont(descriptor: boldFont.fontDescriptor, size: base.pointSize * $0) ?? boldFont }
    }
}

extension Theme {
    /// The colour of each token kind; `SyntaxHighlighter.style` adds the fonts for Markdown.
    static func color(for kind: TokenKind) -> NSColor {
        switch kind {
        case .plain: return text
        case .keyword, .heading, .listMarker, .attributeName: return accent
        case .type, .tag, .link: return cyan
        case .constant, .number, .strong: return yellow
        case .string, .codeSpan, .inserted: return green
        case .escape, .emphasis: return mint
        case .comment, .quote: return commentColor
        case .preprocessor, .attribute, .meta: return purple
        case .function: return blue
        case .property, .variable: return pink
        case .operator, .strikethrough: return textDim
        case .punctuation: return punctuationColor
        case .invalid, .deleted: return red
        }
    }

    static let commentColor = NSColor(hex: 0x6F7785)
    static let punctuationColor = NSColor(hex: 0xB8BEC9)
}
