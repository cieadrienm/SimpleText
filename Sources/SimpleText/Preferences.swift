import AppKit
import SimpleTextCore

/// User settings, read where they are needed. `changed` is posted after every write, from the
/// menu as from the Settings window (SwiftUI writes UserDefaults, which also posts `didChangeNotification`).
enum Preferences {
    static let changed = Notification.Name("net.cieadrienm.simpletext.preferencesChanged")

    enum Key {
        static let fontSize = "fontSize"
        static let fontName = "fontName"
        static let tabWidth = "tabWidth"
        static let indentWithTabs = "indentWithTabs"
        static let wordWrap = "wordWrap"
        static let showLineNumbers = "showLineNumbers"
        static let highlightCurrentLine = "highlightCurrentLine"
        static let autoIndent = "autoIndent"
        static let defaultEncoding = "defaultEncoding"
        static let defaultLineEnding = "defaultLineEnding"
        static let showHiddenFiles = "showHiddenFiles"
    }

    static let defaults: [String: Any] = [
        Key.fontSize: 13.0,
        Key.fontName: "",
        Key.tabWidth: 4,
        Key.indentWithTabs: false,
        Key.wordWrap: true,
        Key.showLineNumbers: true,
        Key.highlightCurrentLine: true,
        Key.autoIndent: true,
        Key.defaultEncoding: Int(String.Encoding.utf8.rawValue),
        Key.defaultLineEnding: LineEnding.lf.rawValue,
        Key.showHiddenFiles: false,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    private static var store: UserDefaults { .standard }

    /// The stored value, or the default when nothing was stored or registered yet (tests, first launch).
    private static func value<T>(_ key: String) -> T {
        (store.object(forKey: key) as? T) ?? (defaults[key] as! T)
    }

    static var fontSize: CGFloat { CGFloat(value(Key.fontSize) as Double) }
    static var fontName: String { value(Key.fontName) }
    static var tabWidth: Int { max(1, value(Key.tabWidth)) }
    static var indentWithTabs: Bool { value(Key.indentWithTabs) }
    static var wordWrap: Bool { value(Key.wordWrap) }
    static var showLineNumbers: Bool { value(Key.showLineNumbers) }
    static var highlightCurrentLine: Bool { value(Key.highlightCurrentLine) }
    static var autoIndent: Bool { value(Key.autoIndent) }
    static var defaultEncoding: String.Encoding {
        let raw: Int = value(Key.defaultEncoding)
        return raw > 0 ? String.Encoding(rawValue: UInt(raw)) : .utf8
    }
    static var defaultLineEnding: LineEnding { LineEnding(rawValue: value(Key.defaultLineEnding)) ?? .lf }
    static var showHiddenFiles: Bool {
        get { value(Key.showHiddenFiles) }
        set { store.set(newValue, forKey: Key.showHiddenFiles) }
    }
    static var indentStyle: IndentStyle { IndentStyle(usesTabs: indentWithTabs, width: tabWidth) }

    static var editorFont: NSFont { Theme.editorFont(name: fontName, size: fontSize) }

    static func set(_ value: Any?, for key: String) {
        store.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}
