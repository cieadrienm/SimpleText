import Foundation
import Observation

/// What the status bar shows; the editor controller writes it, SwiftUI reads it.
@Observable
final class EditorModel {
    var line = 1
    var column = 1
    var selectedCharacters = 0
    var selectedLines = 0
    var lines = 1
    /// nil while the count is not worth computing (very large files).
    var words: Int? = 0
    var languageName = ""
    var encodingName = "UTF-8"
    var lineEndingName = "LF"
    var indentLabel = ""
    var highlighted = true
    /// RTF: fonts and colours are the file's; language, encoding and line-ending menus make no sense.
    var isRichText = false
}

/// Status bar menus and buttons call back into the editor controller and the app.
struct StatusBarActions {
    var pickLanguage: (String) -> Void = { _ in }
    var pickEncoding: (UInt) -> Void = { _ in }
    var pickLineEnding: (String) -> Void = { _ in }
    var showHelp: () -> Void = {}
    var showShortcuts: () -> Void = {}
    var showAbout: () -> Void = {}
    var showUpdate: () -> Void = {}
}
