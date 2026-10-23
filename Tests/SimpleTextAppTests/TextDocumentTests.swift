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
