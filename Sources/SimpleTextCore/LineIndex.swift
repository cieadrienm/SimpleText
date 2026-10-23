import Foundation

/// UTF-16 offsets where each line starts, so line and column questions cost a binary search.
public struct LineIndex: Sendable {
    public let lineStarts: [Int]

    public init(_ text: String) {
        var starts = [0]
        var offset = 0
        for unit in text.utf16 {
            offset += 1
            if unit == 10 { starts.append(offset) }
        }
        lineStarts = starts
    }

    public var lineCount: Int { lineStarts.count }

    /// Zero-based line holding `offset`; an offset past the end belongs to the last line.
    public func line(containing offset: Int) -> Int {
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low
    }

    public func start(ofLine line: Int) -> Int {
        lineStarts[max(0, min(line, lineStarts.count - 1))]
    }

    /// Zero-based line and column (UTF-16 units from the line start).
    public func position(of offset: Int) -> (line: Int, column: Int) {
        let line = line(containing: offset)
        return (line, offset - lineStarts[line])
    }
}

public struct TextStatistics: Equatable, Sendable {
    public var lines: Int
    public var words: Int
    public var characters: Int

    public init(lines: Int, words: Int, characters: Int) {
        self.lines = lines
        self.words = words
        self.characters = characters
    }

    public static func measure(_ text: String) -> TextStatistics {
        var lines = 1, words = 0, characters = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            characters += 1
            if scalar == "\n" { lines += 1 }
            if scalar.properties.isWhitespace {
                inWord = false
            } else if !inWord {
                inWord = true
                words += 1
            }
        }
        return TextStatistics(lines: lines, words: words, characters: characters)
    }
}

/// Indentation of a document: tabs, or a number of spaces.
public struct IndentStyle: Equatable, Sendable {
    public var usesTabs: Bool
    public var width: Int

    public init(usesTabs: Bool, width: Int) {
        self.usesTabs = usesTabs
        self.width = max(1, width)
    }

    public var unit: String { usesTabs ? "\t" : String(repeating: " ", count: width) }

    public var label: String { usesTabs ? "Tabulations" : "Espaces : \(width)" }

    /// Tabs when the first indented lines use them, else the smallest indent seen (2, 3, 4 or 8); `fallback` otherwise.
    public static func detect(in text: String, fallback: IndentStyle) -> IndentStyle {
        var smallest = 0
        var seen = 0
        var atLineStart = true
        var spaces = 0
        for byte in text.utf8 {
            if atLineStart {
                if byte == 9 { return IndentStyle(usesTabs: true, width: fallback.width) }
                if byte == 32 { spaces += 1; continue }
                if spaces > 0, byte != 10, byte != 13 {
                    if smallest == 0 || spaces < smallest { smallest = spaces }
                    seen += 1
                    if seen >= 200 { break }
                }
                spaces = 0
                atLineStart = false
            }
            if byte == 10 { atLineStart = true; spaces = 0 }
        }
        if [2, 3, 4, 8].contains(smallest) { return IndentStyle(usesTabs: false, width: smallest) }
        return fallback
    }
}
