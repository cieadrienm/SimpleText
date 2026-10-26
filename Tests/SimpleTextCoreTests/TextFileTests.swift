import Foundation
import Testing
@testable import SimpleTextCore

@Suite("TextFile")
struct TextFileTests {
    @Test("UTF-8 without BOM reads and writes byte for byte")
    func utf8RoundTrip() throws {
        let text = "été — café\nligne 2\n"
        let data = Data(text.utf8)
        let decoded = try TextFile.decode(data)
        #expect(decoded.text == text)
        #expect(decoded.encoding == .utf8)
        #expect(decoded.hasBOM == false)
        #expect(decoded.lineEnding == .lf)
        let written = try TextFile.encode(decoded.text, encoding: decoded.encoding, bom: decoded.hasBOM, lineEnding: decoded.lineEnding!)
        #expect(written == data)
    }

    @Test("A UTF-8 byte order mark is kept through a round trip")
    func bom() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("hello".utf8)
        let decoded = try TextFile.decode(data)
        #expect(decoded.text == "hello")
        #expect(decoded.hasBOM)
        let written = try TextFile.encode(decoded.text, encoding: .utf8, bom: true, lineEnding: .lf)
        #expect(written == data)
    }

    @Test("CRLF is normalised to LF in memory and restored on write, byte-identical")
    func crlfRoundTrip() throws {
        let data = Data("a\r\nb\r\nc".utf8)
        let decoded = try TextFile.decode(data)
        #expect(decoded.text == "a\nb\nc")
        #expect(decoded.lineEnding == .crlf)
        let written = try TextFile.encode(decoded.text, encoding: .utf8, bom: false, lineEnding: .crlf)
        #expect(written == data)
    }

    @Test("The majority ending wins in a mixed file")
    func mixedEndings() {
        #expect(LineEnding.detect(in: "a\r\nb\r\nc\nd") == .crlf)
        #expect(LineEnding.detect(in: "a\rb\rc") == .cr)
        #expect(LineEnding.detect(in: "no break") == nil)
    }

    @Test("Latin-1 text that is not UTF-8 still opens")
    func latin1Fallback() throws {
        let data = "café".data(using: .isoLatin1)!
        let decoded = try TextFile.decode(data)
        #expect(decoded.text == "café")
        #expect(decoded.encoding != .utf8)
    }

    @Test("A NUL byte marks a binary file")
    func binary() {
        #expect(TextFile.isBinary(Data([0x89, 0x50, 0x4E, 0x47, 0, 1])))
        #expect(!TextFile.isBinary(Data("plain text\n".utf8)))
        #expect(!TextFile.isBinary(Data()))
    }

    @Test("Writing in an encoding that lacks a character fails instead of losing it")
    func unencodable() {
        #expect(throws: TextFileError.self) {
            try TextFile.encode("été", encoding: .ascii, bom: false, lineEnding: .lf)
        }
    }
}

@Suite("LineIndex and text helpers")
struct LineIndexTests {
    @Test("Lines and columns are found by offset")
    func positions() {
        let index = LineIndex("ab\ncd\n\nefg")
        #expect(index.lineCount == 4)
        #expect(index.position(of: 0) == (0, 0))
        #expect(index.position(of: 2) == (0, 2))
        #expect(index.position(of: 3) == (1, 0))
        #expect(index.position(of: 6) == (2, 0))
        #expect(index.position(of: 9) == (3, 2))
        #expect(index.position(of: 99) == (3, 92))
        #expect(index.start(ofLine: 3) == 7)
    }

    @Test("Statistics count lines, words and characters")
    func statistics() {
        let stats = TextStatistics.measure("un deux\n  trois\n")
        #expect(stats == TextStatistics(lines: 3, words: 3, characters: 16))
        #expect(TextStatistics.measure("") == TextStatistics(lines: 1, words: 0, characters: 0))
    }

    @Test("Indentation is read from the file: tabs, then the smallest space indent")
    func indentation() {
        let fallback = IndentStyle(usesTabs: false, width: 4)
        #expect(IndentStyle.detect(in: "a\n\tb\n", fallback: fallback) == IndentStyle(usesTabs: true, width: 4))
        #expect(IndentStyle.detect(in: "a\n  b\n    c\n", fallback: fallback) == IndentStyle(usesTabs: false, width: 2))
        #expect(IndentStyle.detect(in: "a\nb\n", fallback: fallback) == fallback)
        #expect(IndentStyle(usesTabs: false, width: 2).unit == "  ")
    }

    @Test("Files map to languages by name and extension; .h is Objective-C")
    func languages() {
        #expect(Language.forFile(named: "Shape.h").name == "Objective-C")
        #expect(Language.forFile(named: "main.c").name == "C")
        #expect(Language.forFile(named: "App.cs").name == "C#")
        #expect(Language.forFile(named: "index.php").name == "PHP")
        #expect(Language.forFile(named: "README.md").name == "Markdown")
        #expect(Language.forFile(named: "Player.swift").name == "Swift")
        #expect(Language.forFile(named: "page.HTML").name == "HTML")
        #expect(Language.forFile(named: "/tmp/Makefile").name == "Makefile")
        #expect(Language.forFile(named: "notes").name == "Texte brut")
        #expect(Language.forFile(named: "data.bin").name == "Texte brut")
        #expect(Language.named("Swift")?.lineComment == "//")
    }

    @Test("Bilingual localization switches between French and English")
    func localization() {
        let saved = Localization.current
        defer { Localization.current = saved }

        Localization.current = .fr
        #expect(!Localization.isEnglish)
        #expect(L("Fichier", "File") == "Fichier")
        #expect(Language.plainText.displayName == "Texte brut")
        #expect(IndentStyle(usesTabs: true, width: 4).label == "Tabulations")
        #expect(IndentStyle(usesTabs: false, width: 4).label == "Espaces : 4")

        Localization.current = .en
        #expect(Localization.isEnglish)
        #expect(L("Fichier", "File") == "File")
        #expect(Language.plainText.displayName == "Plain Text")
        #expect(IndentStyle(usesTabs: true, width: 4).label == "Tabs")
        #expect(IndentStyle(usesTabs: false, width: 4).label == "Spaces: 4")
    }
}
