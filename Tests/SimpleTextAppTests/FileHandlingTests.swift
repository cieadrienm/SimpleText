import AppKit
import Testing
@testable import SimpleText
@testable import SimpleTextCore

@Suite("Open panel, recent documents, encodings")
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
    }

    @Test("Fichier ▸ Ouvrir l’élément récent lists the recent files and ends with Effacer le menu")
    func recentMenu() throws {
        let delegate = AppDelegate()
        let controller = DocumentController()
        delegate.documentController = controller
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("simpletext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("recent.swift")
        try "let a = 1".write(to: file, atomically: true, encoding: .utf8)
        // AppKit keeps the real list in the app's defaults; the menu is built from whatever it hands over.
        var recent = [file]
        delegate.recentDocumentURLs = { recent }
        let menu = NSMenu(title: "Ouvrir l’élément récent")
        delegate.menuNeedsUpdate(menu)
        let titles = menu.items.map(\.title)
        #expect(titles.first == "recent.swift")
        #expect(titles.last == "Effacer le menu")
        #expect(menu.items.first?.representedObject as? URL == file)
        #expect(menu.items.first?.action == #selector(AppDelegate.openRecentDocument(_:)))
        recent = []
        delegate.menuNeedsUpdate(menu)
        #expect(menu.items.first?.title == "Aucun élément récent")
        #expect(menu.items.first?.isEnabled == false)
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
}
