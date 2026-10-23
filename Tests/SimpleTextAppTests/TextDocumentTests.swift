import AppKit
import Testing
@testable import SimpleText
@testable import SimpleTextCore

@Suite("TextDocument and editor")
@MainActor
struct TextDocumentTests {
    @Test("A document reads CRLF Latin-1 data and writes it back unchanged")
    func roundTrip() throws {
        let document = TextDocument()
        let data = "héllo\r\nworld".data(using: .isoLatin1)!
        try document.read(from: data, ofType: DocumentController.textType)
        #expect(document.text == "héllo\nworld")
        #expect(document.lineEnding == .crlf)
        #expect(try document.data(ofType: DocumentController.textType) == data)
    }

    @Test("Binary data is refused")
    func binary() {
        let document = TextDocument()
        #expect(throws: TextFileError.self) {
            try document.read(from: Data([0x00, 0x01, 0x02]), ofType: DocumentController.textType)
        }
    }

    @Test("The editor keeps TextKit 2 and every smart text feature off")
    func editorSetup() {
        let document = TextDocument()
        document.replaceText(with: "let a = \"quoted\"\n")
        let controller = EditorViewController(document: document)
        controller.loadView()
        let textView = controller.textView!
        #expect(textView.textLayoutManager != nil)
        #expect(textView.smartFeaturesDisabled)
        #expect(textView.allowsUndo)
        textView.applyFont(Preferences.editorFont, tabWidth: 4)
        #expect(textView.textLayoutManager != nil)
        #expect(textView.currentLineRect() != nil)
    }

    @Test("Typing dirties the document, undo cleans it, attribute changes never dirty it")
    func dirtyState() {
        let document = TextDocument()
        let controller = EditorViewController(document: document)
        controller.loadView()
        let textView = controller.textView!
        #expect(!document.isDocumentEdited)
        textView.insertText("abc", replacementRange: NSRange(location: 0, length: 0))
        // The undo group, and with it the change count, closes with the event loop cycle.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(document.isDocumentEdited)
        #expect(document.text == "abc")
        document.undoManager?.undo()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(document.text == "")
        #expect(!document.isDocumentEdited)
        textView.insertText("xyz", replacementRange: NSRange(location: 0, length: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        document.updateChangeCount(.changeCleared)
        textView.applyFont(Preferences.editorFont, tabWidth: 2)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(!document.isDocumentEdited)
    }

    @Test("Line commands: duplicate, delete, move, indent, comment")
    func lineCommands() {
        let document = TextDocument()
        document.languageOverride = Language.named("Swift")
        document.replaceText(with: "one\ntwo\nthree")
        let controller = EditorViewController(document: document)
        controller.loadView()
        let textView = controller.textView!
        textView.indentStyle = IndentStyle(usesTabs: false, width: 2)

        textView.setSelectedRange(NSRange(location: 5, length: 0)) // inside "two"
        textView.duplicateLine(nil)
        #expect(document.text == "one\ntwo\ntwo\nthree")
        #expect(textView.selectedRange().location == 9)

        textView.deleteLine(nil)
        #expect(document.text == "one\ntwo\nthree")

        textView.setSelectedRange(NSRange(location: 9, length: 0)) // inside "three"
        textView.moveLineUp(nil)
        #expect(document.text == "one\nthree\ntwo")
        textView.moveLineDown(nil)
        #expect(document.text == "one\ntwo\nthree")

        textView.setSelectedRange(NSRange(location: 0, length: document.text.utf16.count))
        textView.indentSelection(nil)
        #expect(document.text == "  one\n  two\n  three")
        textView.toggleComment(nil)
        #expect(document.text == "  // one\n  // two\n  // three")
        textView.toggleComment(nil)
        #expect(document.text == "  one\n  two\n  three")
        textView.outdentSelection(nil)
        #expect(document.text == "one\ntwo\nthree")

        textView.setSelectedRange(NSRange(location: 3, length: 0))
        textView.insertText(" {", replacementRange: textView.selectedRange())
        textView.insertNewline(nil)
        #expect(document.text == "one {\n  \ntwo\nthree")
        #expect(textView.selectedRange().location == 8)
    }
}

@Suite("Syntax highlighting in the editor")
@MainActor
struct HighlighterTests {
    private func color(at offset: Int, in document: TextDocument) -> NSColor? {
        document.textStorage.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? NSColor
    }

    @Test("A Swift document is coloured on load, without dirtying it")
    func initialHighlight() {
        let document = TextDocument()
        document.languageOverride = Language.named("Swift")
        document.replaceText(with: "let name = \"x\" // c\nfunc f() {}")
        let controller = EditorViewController(document: document)
        controller.loadView()
        #expect(color(at: 0, in: document) == Theme.accent)        // let
        #expect(color(at: 4, in: document) == Theme.text)          // name
        #expect(color(at: 11, in: document) == Theme.green)        // "x"
        #expect(color(at: 15, in: document) == Theme.commentColor) // // c
        #expect(color(at: 20, in: document) == Theme.accent)       // func
        #expect(color(at: 25, in: document) == Theme.blue)         // f
        #expect(!document.isDocumentEdited)
        #expect(controller.textView.textLayoutManager != nil)
    }

    @Test("An edit re-lexes the changed lines and the ones its state reaches")
    func incrementalHighlight() {
        let document = TextDocument()
        document.languageOverride = Language.named("Swift")
        document.replaceText(with: "let a = 1\nlet b = 2\nlet c = 3")
        let controller = EditorViewController(document: document)
        controller.loadView()
        let textView = controller.textView!
        // Open a block comment on line 1: lines 2 and 3 must turn into comment.
        textView.insertText("/* ", replacementRange: NSRange(location: 0, length: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(color(at: 3, in: document) == Theme.commentColor)
        #expect(color(at: 14, in: document) == Theme.commentColor)
        #expect(color(at: 24, in: document) == Theme.commentColor)
        #expect(controller.highlighter.lineStarts == [0, 13, 23])
        // Close it on line 2: line 3 goes back to code.
        textView.insertText(" */", replacementRange: NSRange(location: 22, length: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(color(at: 26, in: document) == Theme.accent)
        // A new line in the middle keeps the index right.
        textView.insertText("\n", replacementRange: NSRange(location: 13, length: 0))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(controller.highlighter.lineStarts == [0, 13, 14, 27])
        #expect(controller.highlighter.line(containing: 20) == 2)
    }

    @Test("Highlighting a 1 MB file stays under a second")
    func largeFile() {
        let unit = "import AVFoundation\n/// Plays a clip\nfinal class Player { var gain: Float = 0.5 /* x */ }\nlet s = \"text \\(a)\"\n"
        let text = String(repeating: unit, count: 1_000_000 / unit.utf8.count)
        let document = TextDocument()
        document.languageOverride = Language.named("Swift")
        document.replaceText(with: text)
        let started = Date()
        let controller = EditorViewController(document: document)
        controller.loadView()
        controller.highlighter.flush()
        let elapsed = Date().timeIntervalSince(started)
        print("highlight 1 MB:", Int(elapsed * 1000), "ms,", controller.highlighter.lineStarts.count, "lines")
        #if DEBUG
        #expect(elapsed < 6.0)
        #else
        #expect(elapsed < 1.0)
        #endif
        #expect(color(at: 0, in: document) == Theme.accent)
        #expect(color(at: text.utf16.count - 3, in: document) == Theme.green)
    }
}
