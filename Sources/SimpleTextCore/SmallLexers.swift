import Foundation

/// YAML: keys, list dashes, strings, numbers, booleans, anchors and comments, line by line.
public struct YAMLLexer: Lexer {
    public init() {}

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        var i = line.firstNonBlank(from: line.startIndex)
        let end = line.endIndex
        guard i < end else { return [] }
        if line.starts(with: "---".utf16Units, at: i) || line.starts(with: "...".utf16Units, at: i) {
            return [Token(.meta, i..<end)]
        }
        if line[i] == 35 { return [Token(.comment, i..<end)] }
        if line[i] == 45, Chars.isSpace(line.at(i + 1)) || i + 1 == end {
            tokens.append(Token(.listMarker, i..<i + 1))
            i = line.firstNonBlank(from: i + 1)
        }
        // key: value — the key ends at the first ": " or a ":" closing the line.
        var j = i
        if i < end, line[i] != 34, line[i] != 39 {
            while j < end {
                if line[j] == 58, Chars.isSpace(line.at(j + 1)) || j + 1 == end { break }
                if line[j] == 35, Chars.isSpace(line.at(j - 1)) { j = end; break }
                j += 1
            }
            if j < end, line[j] == 58 {
                tokens.append(Token(.property, i..<j))
                tokens.append(Token(.punctuation, j..<j + 1))
                i = line.firstNonBlank(from: j + 1)
            }
        } else if i < end, let close = line.find([line[i]], from: i + 1), line.at(close + 1) == 58 {
            tokens.append(Token(.property, i..<close + 1))
            tokens.append(Token(.punctuation, close + 1..<close + 2))
            i = line.firstNonBlank(from: close + 2)
        }
        tokens += value(line, from: i)
        return tokens
    }

    private static let constants: Set<String> = ["true", "false", "null", "yes", "no", "on", "off", "~", "True", "False", "Null", "TRUE", "FALSE", "NULL"]

    private func value(_ line: Line, from start: Int) -> [Token] {
        var tokens: [Token] = []
        var i = start
        let end = line.endIndex
        while i < end {
            let c = line[i]
            if Chars.isSpace(c) { i += 1; continue }
            if c == 35 /* # */ { tokens.append(Token(.comment, i..<end)); return tokens }
            if c == 34 || c == 39 {
                let close = line.find([c], from: i + 1)
                tokens.append(Token(.string, i..<(close.map { $0 + 1 } ?? end)))
                i = close.map { $0 + 1 } ?? end
                continue
            }
            if c == 38 || c == 42 /* & * */ {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 { j += 1 }
                tokens.append(Token(.meta, i..<j))
                i = j
                continue
            }
            if c == 33 /* ! */ {
                var j = i + 1
                while j < end, !Chars.isSpace(line[j]) { j += 1 }
                tokens.append(Token(.attribute, i..<j))
                i = j
                continue
            }
            if c == 124 || c == 62, i + 1 == end || Chars.isSpace(line.at(i + 1)) || line.at(i + 1) == 45 || line.at(i + 1) == 43 {
                tokens.append(Token(.operator, i..<end))
                return tokens
            }
            if c == 91 || c == 93 || c == 123 || c == 125 || c == 44 {
                tokens.append(Token(.punctuation, i..<i + 1))
                i += 1
                continue
            }
            var j = i
            while j < end, !Chars.isSpace(line[j]), line[j] != 44, line[j] != 93, line[j] != 125 { j += 1 }
            let word = line.string(i..<j)
            if Self.constants.contains(word) {
                tokens.append(Token(.constant, i..<j))
            } else if Double(word) != nil || word.hasPrefix("0x") {
                tokens.append(Token(.number, i..<j))
            }
            i = max(j, i + 1)
        }
        return tokens
    }
}

/// Unified diffs and patches: added, removed, hunk headers, file headers.
public struct DiffLexer: Lexer {
    public init() {}

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        let start = line.startIndex
        let end = line.endIndex
        guard start < end else { return [] }
        if line.starts(with: "+++".utf16Units, at: start) || line.starts(with: "---".utf16Units, at: start) {
            return [Token(.meta, start..<end)]
        }
        if line.starts(with: "@@".utf16Units, at: start) { return [Token(.attribute, start..<end)] }
        if line.starts(with: "diff ".utf16Units, at: start) || line.starts(with: "index ".utf16Units, at: start) {
            return [Token(.comment, start..<end)]
        }
        switch line[start] {
        case 43: return [Token(.inserted, start..<end)]
        case 45: return [Token(.deleted, start..<end)]
        default: return []
        }
    }
}

/// INI and TOML: sections, keys, strings, numbers, booleans, `#` and `;` comments.
public struct ConfigLexer: Lexer {
    public init() {}

    private static let constants: Set<String> = ["true", "false", "yes", "no", "on", "off", "inf", "nan"]

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        var i = line.firstNonBlank(from: line.startIndex)
        let end = line.endIndex
        guard i < end else { return [] }
        let c = line[i]
        if c == 35 || c == 59 { return [Token(.comment, i..<end)] }
        if c == 91 /* [ */ {
            let close = line.find([93], from: i).map { line.at($0 + 1) == 93 ? $0 + 2 : $0 + 1 } ?? end
            tokens.append(Token(.tag, i..<close))
            if let hash = line.find([35], from: close) { tokens.append(Token(.comment, hash..<end)) }
            return tokens
        }
        if let equals = line.find([61], from: i) {
            var keyEnd = equals
            while keyEnd > i, Chars.isSpace(line[keyEnd - 1]) { keyEnd -= 1 }
            tokens.append(Token(.property, i..<keyEnd))
            tokens.append(Token(.operator, equals..<equals + 1))
            i = equals + 1
        }
        while i < end {
            let unit = line[i]
            if Chars.isSpace(unit) { i += 1; continue }
            if unit == 35 /* # */ { tokens.append(Token(.comment, i..<end)); return tokens }
            if unit == 34 || unit == 39 {
                let triple = line.at(i + 1) == unit && line.at(i + 2) == unit
                let pattern = triple ? [unit, unit, unit] : [unit]
                let close = line.find(pattern, from: i + pattern.count)
                tokens.append(Token(.string, i..<(close.map { $0 + pattern.count } ?? end)))
                i = close.map { $0 + pattern.count } ?? end
                continue
            }
            if unit == 91 || unit == 93 || unit == 123 || unit == 125 || unit == 44 {
                tokens.append(Token(.punctuation, i..<i + 1))
                i += 1
                continue
            }
            var j = i
            while j < end, !Chars.isSpace(line[j]), line[j] != 44, line[j] != 93, line[j] != 125 { j += 1 }
            let word = line.string(i..<j)
            if Self.constants.contains(word) {
                tokens.append(Token(.constant, i..<j))
            } else if Chars.isDigit(unit) || unit == 45 || unit == 43 {
                tokens.append(Token(.number, i..<j))
            }
            i = max(j, i + 1)
        }
        return tokens
    }
}
