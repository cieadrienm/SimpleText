import Foundation

/// CSS and SCSS: selectors, at-rules, properties, values with units, strings, comments, nesting.
/// Modes: 0 selectors (aux = open braces), 1 declarations (aux = open braces), 2 block comment.
public struct CSSLexer: Lexer {
    public let scss: Bool

    public init(scss: Bool) {
        self.scss = scss
    }

    private static let commentOpen = "/*".utf16Units
    private static let commentClose = "*/".utf16Units
    private static let important = "!important".utf16Units

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        var i = line.startIndex
        let end = line.endIndex
        // A declaration line that opens a block is really a nested selector (SCSS, and plain CSS at-rules).
        var declarationMode = state.mode == 1
        if declarationMode, state.mode != 2, line.find([123], from: i) != nil, line.find([59], from: i) == nil {
            declarationMode = false
        }
        while i < end {
            let c = line[i]
            if state.mode == 2 {
                if let close = line.find(Self.commentClose, from: i) {
                    tokens.append(Token(.comment, i..<close + 2))
                    i = close + 2
                    state.mode = declarationMode ? 1 : 0
                } else {
                    tokens.append(Token(.comment, i..<end))
                    i = end
                }
                continue
            }
            if Chars.isSpace(c) { i += 1; continue }
            if line.starts(with: Self.commentOpen, at: i) {
                if let close = line.find(Self.commentClose, from: i + 2) {
                    tokens.append(Token(.comment, i..<close + 2))
                    i = close + 2
                } else {
                    tokens.append(Token(.comment, i..<end))
                    state.mode = 2
                    i = end
                }
                continue
            }
            if scss, c == 47, line.at(i + 1) == 47 {
                tokens.append(Token(.comment, i..<end))
                return tokens
            }
            if c == 34 || c == 39 {
                let close = line.find([c], from: i + 1)
                tokens.append(Token(.string, i..<(close.map { $0 + 1 } ?? end)))
                i = close.map { $0 + 1 } ?? end
                continue
            }
            if c == 123 /* { */ {
                tokens.append(Token(.punctuation, i..<i + 1))
                state.aux += 1
                state.mode = 1
                declarationMode = true
                i += 1
                continue
            }
            if c == 125 /* } */ {
                tokens.append(Token(.punctuation, i..<i + 1))
                state.aux = state.aux > 0 ? state.aux - 1 : 0
                state.mode = state.aux > 0 && scss ? 1 : 0
                declarationMode = state.mode == 1
                i += 1
                continue
            }
            if c == 59 /* ; */ || c == 44 || c == 58 && declarationMode {
                tokens.append(Token(.punctuation, i..<i + 1))
                i += 1
                continue
            }
            if scss, c == 36 /* $ */ {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                tokens.append(Token(.variable, i..<j))
                i = j
                continue
            }
            if c == 64 /* @ */ {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                tokens.append(Token(.keyword, i..<j))
                i = j
                continue
            }
            if line.starts(with: Self.important, at: i) {
                tokens.append(Token(.keyword, i..<i + Self.important.count))
                i += Self.important.count
                continue
            }
            if c == 35 /* # */ {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                tokens.append(Token(declarationMode ? .number : .attribute, i..<j))
                i = j
                continue
            }
            if Chars.isDigit(c) || (c == 46 && Chars.isDigit(line.at(i + 1))) || (c == 45 && Chars.isDigit(line.at(i + 1))) {
                var j = i + 1
                while j < end, Chars.isDigit(line[j]) || line[j] == 46 { j += 1 }
                while j < end, Chars.isLetter(line[j]) || line[j] == 37 { j += 1 }
                tokens.append(Token(.number, i..<j))
                i = j
                continue
            }
            if c == 46 /* . */ && !declarationMode {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                tokens.append(Token(.type, i..<j))
                i = j
                continue
            }
            if c == 58 /* : */ && !declarationMode {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 || line[j] == 58 { j += 1 }
                if line.at(j) == 40, let close = line.find([41], from: j) { j = close + 1 }
                tokens.append(Token(.attributeName, i..<j))
                i = j
                continue
            }
            if c == 91 /* [ */ && !declarationMode {
                let close = line.find([93], from: i) ?? end - 1
                tokens.append(Token(.attributeName, i..<close + 1))
                i = close + 1
                continue
            }
            if Chars.isLetter(c) || c == 45 || c == 95 {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                let next = line.firstNonBlank(from: j)
                if declarationMode {
                    if line.at(next) == 58 {
                        tokens.append(Token(.property, i..<j))
                    } else if line.at(next) == 40 {
                        tokens.append(Token(.function, i..<j))
                    } else {
                        tokens.append(Token(.constant, i..<j))
                    }
                } else {
                    tokens.append(Token(line.at(next) == 40 ? .function : .tag, i..<j))
                }
                i = j
                continue
            }
            if c == 62 || c == 43 || c == 126 || c == 42 || c == 38 || c == 61 || c == 47 {
                tokens.append(Token(.operator, i..<i + 1))
                i += 1
                continue
            }
            i += 1
        }
        return tokens
    }
}
