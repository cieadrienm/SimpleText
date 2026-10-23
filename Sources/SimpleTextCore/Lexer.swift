import Foundation

/// What a run of text is, for colouring. The app maps each kind to a colour; the lexers never see colours.
public enum TokenKind: UInt8, CaseIterable, Sendable {
    case plain
    case keyword
    case type
    case constant
    case string
    case escape
    case number
    case comment
    case preprocessor
    case attribute
    case function
    case property
    case tag
    case attributeName
    case variable
    case `operator`
    case punctuation
    case meta
    case heading
    case emphasis
    case strong
    case link
    case codeSpan
    case listMarker
    case quote
    case invalid
    case inserted
    case deleted
}

/// A coloured run; `range` is in UTF-16 units of the document the line was sliced from.
public struct Token: Equatable, Sendable {
    public var kind: TokenKind
    public var range: Range<Int>

    public init(_ kind: TokenKind, _ range: Range<Int>) {
        self.kind = kind
        self.range = range
    }
}

/// What a line hands to the next one: an open comment or string, an embedded language and its own state.
/// Small and comparable, so re-lexing after an edit can stop where the states agree again.
public struct LexState: Hashable, Sendable {
    public var mode: UInt8 = 0
    public var aux: UInt16 = 0
    public var inner: UInt8 = 0
    public var innerAux: UInt16 = 0

    public init() {}

    public static let initial = LexState()
}

/// The line is the slice of the document's UTF-16 units without its line break; token ranges use the
/// slice's own indices, so they are document offsets.
public typealias Line = ArraySlice<UInt16>

public protocol Lexer: Sendable {
    func tokenize(_ line: Line, state: inout LexState) -> [Token]
}

// MARK: - Characters

@usableFromInline
enum Chars {
    @inlinable static func isDigit(_ c: UInt16) -> Bool { c >= 48 && c <= 57 }
    @inlinable static func isHexDigit(_ c: UInt16) -> Bool { isDigit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) }
    @inlinable static func isLetter(_ c: UInt16) -> Bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c > 127 }
    @inlinable static func isUpper(_ c: UInt16) -> Bool { c >= 65 && c <= 90 }
    @inlinable static func isSpace(_ c: UInt16) -> Bool { c == 32 || c == 9 }
    @inlinable static func isWord(_ c: UInt16) -> Bool { isLetter(c) || isDigit(c) || c == 95 }
}

extension ArraySlice<UInt16> {
    /// The unit at `index`, or 0 past the end.
    @inlinable func at(_ index: Int) -> UInt16 {
        index < endIndex ? self[index] : 0
    }

    /// True when `pattern` starts at `index`.
    @inlinable func starts(with pattern: [UInt16], at index: Int) -> Bool {
        guard index + pattern.count <= endIndex else { return false }
        for (offset, unit) in pattern.enumerated() where self[index + offset] != unit { return false }
        return true
    }

    /// Index where `pattern` first appears at or after `index`, or nil.
    @inlinable func find(_ pattern: [UInt16], from index: Int) -> Int? {
        guard !pattern.isEmpty else { return nil }
        var i = index
        let last = endIndex - pattern.count
        while i <= last {
            if self[i] == pattern[0], starts(with: pattern, at: i) { return i }
            i += 1
        }
        return nil
    }

    func string(_ range: Range<Int>) -> String {
        String(utf16CodeUnits: Array(self[range]), count: range.count)
    }

    /// Index of the first unit that is not a space or tab.
    @inlinable func firstNonBlank(from index: Int) -> Int {
        var i = index
        while i < endIndex, Chars.isSpace(self[i]) { i += 1 }
        return i
    }
}

extension String {
    var utf16Units: [UInt16] { Array(utf16) }
}

// MARK: - Table-driven lexer for C-like and script languages

public struct StringRule: Sendable {
    public var open: [UInt16]
    public var close: [UInt16]
    public var escape: UInt16?
    public var multiline: Bool
    /// Char literals: no closing quote within this many units means it was not a literal (Rust lifetimes).
    public var maxLength: Int?
    /// Doubling the closing quote keeps it in the string (SQL, C# verbatim).
    public var doubledClose: Bool

    public init(_ open: String, _ close: String, escape: Character? = "\\", multiline: Bool = false, maxLength: Int? = nil, doubledClose: Bool = false) {
        self.open = open.utf16Units
        self.close = close.utf16Units
        self.escape = escape?.utf16.first
        self.multiline = multiline
        self.maxLength = maxLength
        self.doubledClose = doubledClose
    }
}

/// Everything a language needs beyond its name: comments, strings, word lists and a few switches.
public struct Syntax: Sendable {
    public var lineComments: [[UInt16]] = []
    public var blockComment: (open: [UInt16], close: [UInt16])?
    public var nestedBlockComments = false
    public var strings: [StringRule] = []
    public var keywords: Set<String> = []
    public var types: Set<String> = []
    public var constants: Set<String> = []
    /// `#` at the start of a line begins a preprocessor directive (C family).
    public var preprocessor = false
    /// Words starting with this unit (`@`, `#` in Swift…) and what they are.
    public var annotation: (prefix: UInt16, kind: TokenKind)?
    /// `$name` (PHP, Shell, Perl) or `@name` (Ruby).
    public var variablePrefix: UInt16?
    public var capitalizedTypes = false
    public var functionCalls = true
    public var memberProperties = true
    public var caseInsensitiveKeywords = false
    /// Units allowed inside identifiers besides letters, digits and `_`.
    public var identifierExtras: [UInt16] = []
    /// A word followed by `:` at the start of a line is a label or a target (Makefile, YAML-like).
    public var lineLabels = false
    /// A string followed by `:` names a property (JSON).
    public var stringKeys = false

    public init() {}

    public init(
        lineComments: [String] = [],
        blockComment: (String, String)? = nil,
        nestedBlockComments: Bool = false,
        strings: [StringRule] = [],
        keywords: Set<String> = [],
        types: Set<String> = [],
        constants: Set<String> = [],
        preprocessor: Bool = false,
        annotation: (Character, TokenKind)? = nil,
        variablePrefix: Character? = nil,
        capitalizedTypes: Bool = false,
        functionCalls: Bool = true,
        memberProperties: Bool = true,
        caseInsensitiveKeywords: Bool = false,
        identifierExtras: String = "",
        lineLabels: Bool = false,
        stringKeys: Bool = false
    ) {
        self.lineComments = lineComments.map(\.utf16Units)
        self.blockComment = blockComment.map { ($0.0.utf16Units, $0.1.utf16Units) }
        self.nestedBlockComments = nestedBlockComments
        self.strings = strings.sorted { $0.open.count > $1.open.count }
        self.keywords = caseInsensitiveKeywords ? Set(keywords.map { $0.lowercased() }) : keywords
        self.types = types
        self.constants = constants
        self.preprocessor = preprocessor
        self.annotation = annotation.map { ($0.0.utf16.first!, $0.1) }
        self.variablePrefix = variablePrefix?.utf16.first
        self.capitalizedTypes = capitalizedTypes
        self.functionCalls = functionCalls
        self.memberProperties = memberProperties
        self.caseInsensitiveKeywords = caseInsensitiveKeywords
        self.identifierExtras = identifierExtras.utf16Units
        self.lineLabels = lineLabels
        self.stringKeys = stringKeys
    }
}

/// Lexer for every language whose rules fit a `Syntax`: C, Objective-C, C#, Swift, PHP, Python, Shell…
/// Modes: 0 normal, 1 block comment (aux = depth), 2 inside a multi-line string (aux = rule index).
public struct GenericLexer: Lexer {
    public let syntax: Syntax

    public init(_ syntax: Syntax) {
        self.syntax = syntax
    }

    private static let operatorUnits: Set<UInt16> = Set("+-*/%=<>!&|^~?:".utf16)
    private static let punctuationUnits: Set<UInt16> = Set("()[]{};,.".utf16)

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        var i = line.startIndex
        let end = line.endIndex

        // Finish whatever the previous line left open.
        if state.mode == 1, let block = syntax.blockComment {
            let start = i
            i = scanBlockComment(line, from: i, close: block.close, open: block.open, state: &state)
            tokens.append(Token(.comment, start..<i))
        } else if state.mode == 2 {
            let rule = syntax.strings[Int(state.aux)]
            let start = i
            i = scanString(line, from: i, rule: rule, opened: true, state: &state)
            tokens.append(Token(.string, start..<i))
        }

        var lineStart = true
        while i < end {
            let c = line[i]
            if Chars.isSpace(c) {
                i += 1
                continue
            }
            if lineStart, syntax.preprocessor, c == 35 /* # */ {
                tokens.append(Token(.preprocessor, i..<end))
                return tokens
            }
            if lineStart, syntax.lineLabels, Chars.isLetter(c) || c == 46 || c == 95 {
                var j = i
                while j < end, Chars.isWord(line[j]) || line[j] == 46 || line[j] == 45 || line[j] == 47 { j += 1 }
                if line.at(j) == 58, line.at(j + 1) != 61 /* := */ {
                    tokens.append(Token(.function, i..<j))
                    tokens.append(Token(.punctuation, j..<j + 1))
                    i = j + 1
                    lineStart = false
                    continue
                }
            }
            lineStart = false

            if let comment = syntax.lineComments.first(where: { line.starts(with: $0, at: i) }), !comment.isEmpty {
                tokens.append(Token(.comment, i..<end))
                return tokens
            }
            if let block = syntax.blockComment, line.starts(with: block.open, at: i) {
                let start = i
                state.mode = 1
                state.aux = 1
                i = scanBlockComment(line, from: i + block.open.count, close: block.close, open: block.open, state: &state)
                tokens.append(Token(.comment, start..<i))
                continue
            }
            if let (index, rule) = syntax.strings.enumerated().first(where: { line.starts(with: $0.element.open, at: i) }) {
                let start = i
                state.aux = UInt16(index)
                let next = scanString(line, from: i + rule.open.count, rule: rule, opened: false, state: &state)
                if next > 0 {
                    let isKey = syntax.stringKeys && state.mode == 0 && line.at(line.firstNonBlank(from: next)) == 58
                    tokens.append(Token(isKey ? .property : .string, start..<next))
                    i = next
                    continue
                }
                state.aux = 0
            }
            if let annotation = syntax.annotation, c == annotation.prefix, Chars.isLetter(line.at(i + 1)) {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) { j += 1 }
                tokens.append(Token(annotation.kind, i..<j))
                i = j
                continue
            }
            if let prefix = syntax.variablePrefix, c == prefix, Chars.isWord(line.at(i + 1)) || line.at(i + 1) == 123 || line.at(i + 1) == 40 {
                var j = i + 1
                if line[j] == 123 || line[j] == 40 /* { ( */ {
                    let closer: UInt16 = line[j] == 123 ? 125 : 41
                    while j < end, line[j] != closer { j += 1 }
                    j = min(j + 1, end)
                } else {
                    while j < end, Chars.isWord(line[j]) { j += 1 }
                }
                tokens.append(Token(.variable, i..<j))
                i = j
                continue
            }
            if Chars.isDigit(c) || (c == 46 && Chars.isDigit(line.at(i + 1))) {
                let start = i
                i = scanNumber(line, from: i)
                tokens.append(Token(.number, start..<i))
                continue
            }
            if Chars.isLetter(c) || c == 95 {
                let start = i
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || syntax.identifierExtras.contains(line[j]) { j += 1 }
                i = j
                tokens.append(Token(classify(line, word: start..<j, tokens: tokens), start..<j))
                continue
            }
            if Self.operatorUnits.contains(c) {
                var j = i + 1
                while j < end, Self.operatorUnits.contains(line[j]) { j += 1 }
                tokens.append(Token(.operator, i..<j))
                i = j
                continue
            }
            if Self.punctuationUnits.contains(c) {
                tokens.append(Token(.punctuation, i..<i + 1))
                i += 1
                continue
            }
            i += 1
        }
        return tokens
    }

    private func classify(_ line: Line, word: Range<Int>, tokens: [Token]) -> TokenKind {
        var text = line.string(word)
        if syntax.caseInsensitiveKeywords { text = text.lowercased() }
        if syntax.keywords.contains(text) { return .keyword }
        if syntax.constants.contains(text) { return .constant }
        if syntax.types.contains(text) { return .type }
        let next = line.firstNonBlank(from: word.upperBound)
        if syntax.memberProperties, let previous = tokens.last, previous.kind == .punctuation, line[previous.range.lowerBound] == 46 {
            if syntax.functionCalls, line.at(next) == 40 { return .function }
            return .property
        }
        if syntax.capitalizedTypes, Chars.isUpper(line[word.lowerBound]) { return .type }
        if syntax.functionCalls, line.at(next) == 40 /* ( */ { return .function }
        return .plain
    }

    private func scanNumber(_ line: Line, from start: Int) -> Int {
        var i = start
        let end = line.endIndex
        if line[i] == 48, let p = Optional(line.at(i + 1)), p == 120 || p == 88 || p == 98 || p == 66 || p == 111 || p == 79 {
            i += 2
            while i < end, Chars.isHexDigit(line[i]) || line[i] == 95 { i += 1 }
        } else {
            while i < end, Chars.isDigit(line[i]) || line[i] == 95 { i += 1 }
            if line.at(i) == 46, Chars.isDigit(line.at(i + 1)) {
                i += 1
                while i < end, Chars.isDigit(line[i]) || line[i] == 95 { i += 1 }
            }
            if line.at(i) == 101 || line.at(i) == 69 {
                var j = i + 1
                if line.at(j) == 43 || line.at(j) == 45 { j += 1 }
                if Chars.isDigit(line.at(j)) {
                    i = j
                    while i < end, Chars.isDigit(line[i]) { i += 1 }
                }
            }
        }
        // Suffixes: 1.0f, 10u, 42L, 3ms (CSS units are their own lexer).
        while i < end, Chars.isLetter(line[i]) { i += 1 }
        return i
    }

    /// Returns the index after the comment, leaving `state.mode` at 1 when the line ends inside it.
    private func scanBlockComment(_ line: Line, from start: Int, close: [UInt16], open: [UInt16], state: inout LexState) -> Int {
        var i = start
        let end = line.endIndex
        while i < end {
            if syntax.nestedBlockComments, line.starts(with: open, at: i) {
                state.aux += 1
                i += open.count
                continue
            }
            if line.starts(with: close, at: i) {
                i += close.count
                if syntax.nestedBlockComments, state.aux > 1 {
                    state.aux -= 1
                    continue
                }
                state.mode = 0
                state.aux = 0
                return i
            }
            i += 1
        }
        return end
    }

    /// Returns the index after the string, 0 when `rule` does not apply here (a char literal too long),
    /// and leaves `state.mode` at 2 when a multi-line string continues on the next line.
    private func scanString(_ line: Line, from start: Int, rule: StringRule, opened: Bool, state: inout LexState) -> Int {
        var i = start
        let end = line.endIndex
        while i < end {
            if let escape = rule.escape, line[i] == escape {
                i += 2
                continue
            }
            if line.starts(with: rule.close, at: i) {
                if rule.doubledClose, line.starts(with: rule.close, at: i + rule.close.count) {
                    i += rule.close.count * 2
                    continue
                }
                state.mode = 0
                state.aux = 0
                return i + rule.close.count
            }
            i += 1
        }
        if let maxLength = rule.maxLength, !opened, end - start + rule.open.count > maxLength {
            return 0
        }
        if rule.multiline {
            state.mode = 2
        } else {
            state.mode = 0
            state.aux = 0
        }
        return end
    }
}
