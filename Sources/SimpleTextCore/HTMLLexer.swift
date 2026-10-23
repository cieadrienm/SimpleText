import Foundation

/// HTML, with PHP blocks, `<script>` and `<style>` coloured by their own lexers. A `.php` file starts
/// in HTML, as PHP itself does. Modes: 0 text, 1 inside a tag (aux: 1 script, 2 style), 2 comment,
/// 3 script, 4 style, 5 PHP, 6 inside a quoted attribute value (aux = quote, high byte = tag kind).
public struct HTMLLexer: Lexer {
    public let allowsPHP: Bool

    public init(allowsPHP: Bool = true) {
        self.allowsPHP = allowsPHP
    }

    private static let commentOpen = "<!--".utf16Units
    private static let commentClose = "-->".utf16Units
    private static let phpOpen = "<?".utf16Units
    private static let phpClose = "?>".utf16Units
    private static let scriptClose = "</script".utf16Units
    private static let styleClose = "</style".utf16Units
    private static let javascript = GenericLexer(Syntaxes.javascript)
    private static let php = GenericLexer(Syntaxes.php)
    private static let css = CSSLexer(scss: false)

    public func tokenize(_ line: Line, state: inout LexState) -> [Token] {
        var tokens: [Token] = []
        var i = line.startIndex
        let end = line.endIndex
        while i < end {
            switch state.mode {
            case 2:
                if let close = line.find(Self.commentClose, from: i) {
                    tokens.append(Token(.comment, i..<close + 3))
                    i = close + 3
                    state.mode = 0
                } else {
                    tokens.append(Token(.comment, i..<end))
                    i = end
                }
            case 3, 4:
                let closer = state.mode == 3 ? Self.scriptClose : Self.styleClose
                let stop = findCaseInsensitive(line, closer, from: i) ?? end
                if stop > i {
                    var inner = LexState()
                    inner.mode = state.inner
                    inner.aux = state.innerAux
                    let slice = line[i..<stop]
                    tokens += state.mode == 3 ? Self.javascript.tokenize(slice, state: &inner) : Self.css.tokenize(slice, state: &inner)
                    state.inner = inner.mode
                    state.innerAux = inner.aux
                }
                i = stop
                if stop < end {
                    state.mode = 0
                    state.inner = 0
                    state.innerAux = 0
                }
            case 5:
                let stop = line.find(Self.phpClose, from: i) ?? end
                if stop > i {
                    var inner = LexState()
                    inner.mode = state.inner
                    inner.aux = state.innerAux
                    tokens += Self.php.tokenize(line[i..<stop], state: &inner)
                    state.inner = inner.mode
                    state.innerAux = inner.aux
                }
                i = stop
                if stop < end {
                    tokens.append(Token(.meta, stop..<stop + 2))
                    i = stop + 2
                    state.mode = 0
                    state.inner = 0
                    state.innerAux = 0
                }
            case 6:
                let quote = UInt16(state.aux & 0xFF)
                let close = line.find([quote], from: i)
                tokens.append(Token(.string, i..<(close.map { $0 + 1 } ?? end)))
                i = close.map { $0 + 1 } ?? end
                if close != nil {
                    state.mode = 1
                    state.aux >>= 8
                }
            case 1:
                i = tokenizeTag(line, from: i, into: &tokens, state: &state)
            default:
                i = tokenizeText(line, from: i, into: &tokens, state: &state)
            }
        }
        return tokens
    }

    private func tokenizeText(_ line: Line, from start: Int, into tokens: inout [Token], state: inout LexState) -> Int {
        var i = start
        let end = line.endIndex
        while i < end {
            let c = line[i]
            if c == 60 /* < */ {
                if line.starts(with: Self.commentOpen, at: i) {
                    if let close = line.find(Self.commentClose, from: i + 4) {
                        tokens.append(Token(.comment, i..<close + 3))
                        return close + 3
                    }
                    tokens.append(Token(.comment, i..<end))
                    state.mode = 2
                    return end
                }
                if allowsPHP, line.starts(with: Self.phpOpen, at: i) {
                    var j = i + 2
                    if line.at(j) == 61 { j += 1 } else { while j < end, Chars.isLetter(line[j]) { j += 1 } }
                    tokens.append(Token(.meta, i..<j))
                    state.mode = 5
                    state.inner = 0
                    state.innerAux = 0
                    return j
                }
                let next = line.at(i + 1)
                if next == 33 /* ! */ {
                    let close = line.find([62], from: i) ?? end
                    tokens.append(Token(.meta, i..<min(close + 1, end)))
                    return min(close + 1, end)
                }
                if Chars.isLetter(next) || next == 47 /* / */ {
                    var j = i + 1
                    if line[j] == 47 { j += 1 }
                    let nameStart = j
                    while j < end, Chars.isWord(line[j]) || line[j] == 45 || line[j] == 58 { j += 1 }
                    tokens.append(Token(.tag, i..<j))
                    let name = line.string(nameStart..<j).lowercased()
                    state.mode = 1
                    state.aux = next == 47 ? 0 : (name == "script" ? 1 : name == "style" ? 2 : 0)
                    return j
                }
                i += 1
            } else if c == 38 /* & */ {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 35 { j += 1 }
                if line.at(j) == 59 {
                    tokens.append(Token(.escape, i..<j + 1))
                    i = j + 1
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        return end
    }

    private func tokenizeTag(_ line: Line, from start: Int, into tokens: inout [Token], state: inout LexState) -> Int {
        var i = start
        let end = line.endIndex
        while i < end {
            let c = line[i]
            if Chars.isSpace(c) { i += 1; continue }
            if c == 62 /* > */ || (c == 47 && line.at(i + 1) == 62) {
                let width = c == 62 ? 1 : 2
                tokens.append(Token(.tag, i..<i + width))
                let kind = state.aux
                state.mode = (c == 62 && kind == 1) ? 3 : (c == 62 && kind == 2) ? 4 : 0
                state.aux = 0
                state.inner = 0
                state.innerAux = 0
                return i + width
            }
            if c == 61 /* = */ {
                tokens.append(Token(.operator, i..<i + 1))
                i += 1
                continue
            }
            if c == 34 || c == 39 {
                if let close = line.find([c], from: i + 1) {
                    tokens.append(Token(.string, i..<close + 1))
                    i = close + 1
                } else {
                    tokens.append(Token(.string, i..<end))
                    state.aux = (state.aux << 8) | UInt16(c)
                    state.mode = 6
                    return end
                }
                continue
            }
            if Chars.isLetter(c) || c == 64 || c == 58 || c == 95 || c == 45 {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 45 || line[j] == 58 || line[j] == 46 { j += 1 }
                tokens.append(Token(.attributeName, i..<j))
                i = j
                continue
            }
            if Chars.isDigit(c) {
                var j = i + 1
                while j < end, Chars.isWord(line[j]) || line[j] == 46 || line[j] == 37 { j += 1 }
                tokens.append(Token(.string, i..<j))
                i = j
                continue
            }
            i += 1
        }
        return end
    }

    private func findCaseInsensitive(_ line: Line, _ pattern: [UInt16], from start: Int) -> Int? {
        var i = start
        let last = line.endIndex - pattern.count
        while i <= last {
            var match = true
            for (offset, unit) in pattern.enumerated() {
                var actual = line[i + offset]
                if actual >= 65 && actual <= 90 { actual += 32 }
                if actual != unit { match = false; break }
            }
            if match { return i }
            i += 1
        }
        return nil
    }
}
