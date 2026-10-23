import AppKit
import SimpleTextCore

/// Colours the document's text storage from a lexer, one line at a time. Each line's end state is
/// kept, so after an edit only the changed lines and those whose state differs are lexed again.
/// Attribute changes go straight to the storage, outside the undo manager: they never dirty the document.
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
        didSet { highlightAll() }
    }

    /// Lexing stops above this size; the text stays in the base colour.
    var limit = TextDocument.highlightLimit

    var isEnabled: Bool { lexer != nil && storage.length <= limit }

    init(storage: NSTextStorage) {
        self.storage = storage
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
            storage.beginEditing()
            storage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: storage.length))
            storage.addAttribute(.foregroundColor, value: Theme.text, range: NSRange(location: 0, length: storage.length))
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
            let tokens = lexer.tokenize(buffer[0..<count], state: &state)
            apply(tokens, lineStart: start, lineLength: count)
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

    private func apply(_ tokens: [Token], lineStart: Int, lineLength: Int) {
        guard lineLength > 0 else { return }
        storage.addAttribute(.foregroundColor, value: Theme.text, range: NSRange(location: lineStart, length: lineLength))
        for token in tokens where token.kind != .plain {
            let range = NSRange(location: lineStart + token.range.lowerBound, length: token.range.count)
            storage.addAttribute(.foregroundColor, value: Theme.color(for: token.kind), range: range)
        }
    }
}

extension Theme {
    /// The colour of each token kind. Colour only: fonts never change, so the layout never moves.
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
        case .operator: return textDim
        case .punctuation: return punctuationColor
        case .invalid, .deleted: return red
        }
    }

    static let commentColor = NSColor(hex: 0x6F7785)
    static let punctuationColor = NSColor(hex: 0xB8BEC9)
}
