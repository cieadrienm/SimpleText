import Foundation

/// Markdown: headings, lists, quotes, rules, fenced code (coloured by the fence's language), inline
/// code, emphasis, links and inline HTML. Modes: 0 text, 1 inside a fence (aux = language index + 1,
/// inner/innerAux = that lexer's state), 2 inside an HTML comment.
public struct MarkdownLexer: Lexer {
    public init() {}

    private static let fenceTick: UInt16 = 96   // `
    private static let fenceTilde: UInt16 = 126 // ~
    private static let commentOpen = "<!--".utf16Units
    private static let commentClose = "-->".utf16Units

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        let start = line.firstNonBlank(from: line.startIndex)
        let end = line.endIndex

        if state.mode == 1 {
            if fenceLength(line, at: start) >= Int(state.innerAux & 0xFF), fenceLength(line, at: start) > 0,
               line.at(start) == (state.innerAux >> 8 == 1 ? Self.fenceTilde : Self.fenceTick) {
                state = .initial
                return [Token(.meta, line.startIndex..<end)]
            }
            if state.aux > 0, let language = Lexers.language(at: state.aux - 1), let lexer = Lexers.lexer(for: language) {
                var inner = LexState()
                inner.mode = state.inner
                let fenceInfo = state.innerAux
                let result = lexer.tokenize(line, state: &inner)
                state.inner = inner.mode
                state.innerAux = fenceInfo
                return result
            }
            return line.isEmpty ? [] : [Token(.codeSpan, line.startIndex..<end)]
        }
        if state.mode == 2 {
            if let close = line.find(Self.commentClose, from: line.startIndex) {
                state.mode = 0
                tokens.append(Token(.comment, line.startIndex..<close + 3))
                tokens += inline(line, from: close + 3)
                return tokens
            }
            return [Token(.comment, line.startIndex..<end)]
        }

        guard start < end else { return [] }
        let c = line[start]

        // ``` or ~~~, with an optional language.
        let fence = fenceLength(line, at: start)
        if fence >= 3 {
            let infoStart = line.firstNonBlank(from: start + fence)
            var infoEnd = infoStart
            while infoEnd < end, !Chars.isSpace(line[infoEnd]) { infoEnd += 1 }
            let name = line.string(infoStart..<infoEnd)
            state.mode = 1
            state.aux = name.isEmpty ? 0 : UInt16(Lexers.languageIndex(forFence: name).map { $0 + 1 } ?? 0)
            state.inner = 0
            state.innerAux = UInt16(fence & 0xFF) | (c == Self.fenceTilde ? 0x100 : 0)
            tokens.append(Token(.meta, line.startIndex..<infoStart))
            if infoEnd > infoStart { tokens.append(Token(.attribute, infoStart..<infoEnd)) }
            return tokens
        }
        if c == 35 /* # */ {
            var level = 0
            while line.at(start + level) == 35 { level += 1 }
            if level <= 6, Chars.isSpace(line.at(start + level)) || start + level == end {
                return [Token(.heading, line.startIndex..<end)]
            }
        }
        if c == 62 /* > */ {
            return [Token(.quote, line.startIndex..<end)]
        }
        if isRule(line, from: start) {
            return [Token(.meta, line.startIndex..<end)]
        }
        if line.starts(with: Self.commentOpen, at: start) {
            if let close = line.find(Self.commentClose, from: start + 4) {
                tokens.append(Token(.comment, start..<close + 3))
                tokens += inline(line, from: close + 3)
            } else {
                state.mode = 2
                tokens.append(Token(.comment, start..<end))
            }
            return tokens
        }
        var contentStart = start
        if (c == 45 || c == 42 || c == 43), Chars.isSpace(line.at(start + 1)) {
            tokens.append(Token(.listMarker, start..<start + 1))
            contentStart = line.firstNonBlank(from: start + 1)
            // Task list boxes.
            if line.at(contentStart) == 91, line.at(contentStart + 2) == 93, Chars.isSpace(line.at(contentStart + 3)) {
                tokens.append(Token(.meta, contentStart..<contentStart + 3))
                contentStart = line.firstNonBlank(from: contentStart + 3)
            }
        } else if Chars.isDigit(c) {
            var j = start
            while Chars.isDigit(line.at(j)) { j += 1 }
            if (line.at(j) == 46 || line.at(j) == 41), Chars.isSpace(line.at(j + 1)), j - start <= 9 {
                tokens.append(Token(.listMarker, start..<j + 1))
                contentStart = line.firstNonBlank(from: j + 1)
            }
        }
        tokens += inline(line, from: contentStart)
        return tokens
    }

    private func fenceLength(_ line: Line, at index: Int) -> Int {
        let unit = line.at(index)
        guard unit == Self.fenceTick || unit == Self.fenceTilde else { return 0 }
        var count = 0
        while line.at(index + count) == unit { count += 1 }
        return count
    }

    private func isRule(_ line: Line, from start: Int) -> Bool {
        let unit = line.at(start)
        guard unit == 45 || unit == 42 || unit == 95 else { return false }
        var count = 0
        var i = start
        while i < line.endIndex {
            if line[i] == unit { count += 1 } else if !Chars.isSpace(line[i]) { return false }
            i += 1
        }
        return count >= 3
    }

    /// Inline spans: code, strong, emphasis, links, images, autolinks, HTML tags, escapes.
    private func inline(_ line: Line, from start: Int) -> [Token] {
        var tokens: [Token] = []
        var i = start
        let end = line.endIndex
        while i < end {
            let c = line[i]
            switch c {
            case 92 /* \ */:
                if i + 1 < end { tokens.append(Token(.escape, i..<i + 2)) }
                i += 2
            case 96 /* ` */:
                var ticks = 0
                while line.at(i + ticks) == 96 { ticks += 1 }
                let pattern = [UInt16](repeating: 96, count: ticks)
                if let close = line.find(pattern, from: i + ticks) {
                    tokens.append(Token(.codeSpan, i..<close + ticks))
                    i = close + ticks
                } else {
                    i += ticks
                }
            case 42 /* * */, 95 /* _ */:
                let double = line.at(i + 1) == c
                let width = double ? 2 : 1
                let next = line.at(i + width)
                guard next != 0, !Chars.isSpace(next), next != c else { i += width; continue }
                let pattern = [UInt16](repeating: c, count: width)
                if let close = line.find(pattern, from: i + width), !Chars.isSpace(line[close - 1]) {
                    tokens.append(Token(double ? .strong : .emphasis, i..<close + width))
                    i = close + width
                } else {
                    i += width
                }
            case 33 /* ! */ where line.at(i + 1) == 91, 91 /* [ */:
                let textStart = c == 33 ? i + 1 : i
                guard let textEnd = line.find([93], from: textStart + 1) else { i += 1; continue }
                if line.at(textEnd + 1) == 40, let urlEnd = line.find([41], from: textEnd + 2) {
                    tokens.append(Token(.link, i..<textEnd + 1))
                    tokens.append(Token(.meta, textEnd + 1..<urlEnd + 1))
                    i = urlEnd + 1
                } else if line.at(textEnd + 1) == 91, let refEnd = line.find([93], from: textEnd + 2) {
                    tokens.append(Token(.link, i..<textEnd + 1))
                    tokens.append(Token(.meta, textEnd + 1..<refEnd + 1))
                    i = refEnd + 1
                } else {
                    tokens.append(Token(.link, i..<textEnd + 1))
                    i = textEnd + 1
                }
            case 60 /* < */:
                guard let close = line.find([62], from: i + 1) else { i += 1; continue }
                let inside = line.string(i + 1..<close)
                if inside.contains("://") || inside.contains("@") {
                    tokens.append(Token(.link, i..<close + 1))
                } else if Chars.isLetter(line.at(i + 1)) || line.at(i + 1) == 47 {
                    tokens.append(Token(.tag, i..<close + 1))
                }
                i = close + 1
            case 124 /* | */:
                tokens.append(Token(.punctuation, i..<i + 1))
                i += 1
            default:
                i += 1
            }
        }
        return tokens
    }
}
