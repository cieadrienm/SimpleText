import AppKit
import Testing
@testable import SimpleText
@testable import SimpleTextCore

@Suite("Open panel, document types, encodings")
@MainActor
struct FileHandlingTests {
    @Test("The open panel accepts any file and shows hidden ones on request, remembered")
    func openPanel() {
        let controller = DocumentController()
        Preferences.showHiddenFiles = false
        let panel = NSOpenPanel()
        controller.configurePanel(panel)
        #expect(panel.allowedContentTypes.isEmpty)
        #expect(panel.canChooseFiles)
        #expect(!panel.showsHiddenFiles)
        let accessory = panel.accessoryView as? HiddenFilesAccessory
        #expect(accessory != nil)
        #expect(accessory?.checkbox.state == .off)
        accessory?.checkbox.state = .on
        if let accessory { accessory.toggle(accessory.checkbox) }
        #expect(panel.showsHiddenFiles)
        #expect(Preferences.showHiddenFiles)
        Preferences.showHiddenFiles = false
        panel.accessoryView = nil
    }

    @Test("Any text file has the text type; a binary one is refused before a document exists")
    func typeForContents() throws {
        let controller = DocumentController()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("simpletext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let noExtension = folder.appendingPathComponent("notes")
        try "plain words".write(to: noExtension, atomically: true, encoding: .utf8)
        #expect(try controller.typeForContents(of: noExtension) == DocumentController.textType)
        let binary = folder.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]).write(to: binary)
        #expect(throws: TextFileError.self) { try controller.typeForContents(of: binary) }
        // RTF by extension, or by header whatever the extension.
        let rtf = folder.appendingPathComponent("note.rtf")
        try "{\\rtf1\\ansi Hello}".write(to: rtf, atomically: true, encoding: .utf8)
        #expect(try controller.typeForContents(of: rtf) == TextDocument.rtfType)
        let disguised = folder.appendingPathComponent("note.txt")
        try "{\\rtf1\\ansi Hello}".write(to: disguised, atomically: true, encoding: .utf8)
        #expect(try controller.typeForContents(of: disguised) == TextDocument.rtfType)
        try "plain".write(to: disguised, atomically: true, encoding: .utf8)
        #expect(try controller.typeForContents(of: disguised) == DocumentController.textType)
    }

    @Test("Changing the encoding of a clean document reads it again from disk")
    func reinterpret() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("simpletext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("latin.txt")
        try "caf\u{E9} \u{201C}ok\u{201D}".data(using: .windowsCP1252)!.write(to: file)
        let document = try TextDocument(contentsOf: file, ofType: DocumentController.textType)
        #expect(document.encoding != .utf8)
        try document.setEncoding(.macOSRoman)
        #expect(document.encoding == .macOSRoman)
        #expect(document.text.hasPrefix("caf"))
        #expect(!document.isDocumentEdited)
        try document.setEncoding(.windowsCP1252)
        #expect(document.text == "caf\u{E9} \u{201C}ok\u{201D}")
        #expect(throws: TextFileError.self) { try document.setEncoding(.ascii) }
        document.setLineEnding(.crlf)
        #expect(document.isDocumentEdited)
        #expect(try document.data(ofType: DocumentController.textType) == "caf\u{E9} \u{201C}ok\u{201D}".data(using: .windowsCP1252))
    }

    @Test("Menus and open panel rebuild in French and English")
    func menuLocalization() {
        let saved = Localization.current
        defer { Preferences.setLanguage(saved) }
        let delegate = AppDelegate()

        Preferences.setLanguage(.fr)
        let frMenu = MainMenu.build(delegate: delegate)
        #expect(frMenu.items.map(\.title) == ["SimpleText", "Fichier", "Édition", "Format", "Présentation", "Fenêtre", "Aide"])
        #expect(frMenu.items.first?.submenu?.items[1].title == "Rechercher des mises à jour…")
        #expect(frMenu.items.last?.submenu?.items.last?.title == "Site web Simple Apps (adrien-m.net/software)")

        Preferences.setLanguage(.en)
        let enMenu = MainMenu.build(delegate: delegate)
        #expect(enMenu.items.map(\.title) == ["SimpleText", "File", "Edit", "Format", "View", "Window", "Help"])
        #expect(enMenu.items.first?.submenu?.items[1].title == "Check for Updates…")
        #expect(enMenu.items.last?.submenu?.items.last?.title == "Simple Apps Website (adrien-m.net/software)")
    }
}
