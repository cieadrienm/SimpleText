import AppKit
import SimpleTextCore
import SwiftUI

/// User settings, read where they are needed. `changed` is posted after every write, from the
/// menu as from the Settings window (SwiftUI writes UserDefaults, which also posts `didChangeNotification`).
enum Preferences {
    static let changed = Notification.Name("net.cieadrienm.simpletext.preferencesChanged")

    enum Key {
        static let language = Localization.defaultsKey
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
        static let hideMarkdownMarkup = "hideMarkdownMarkup"
        static let autoCheckUpdates = SimpleUpdater.autoCheckKey
    }

    static let defaults: [String: Any] = [
        Key.language: AppLanguage.system.rawValue,
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
        Key.hideMarkdownMarkup: false,
        Key.autoCheckUpdates: true,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    private static var store: UserDefaults { .standard }

    /// The stored value, or the default when nothing was stored or registered yet (tests, first launch).
    /// Booleans go through `bool(forKey:)`: a `-key 1` on the command line arrives as a string.
    private static func value<T>(_ key: String) -> T {
        if T.self == Bool.self, store.object(forKey: key) != nil { return store.bool(forKey: key) as! T }
        return (store.object(forKey: key) as? T) ?? (defaults[key] as! T)
    }

    static var language: AppLanguage {
        get { Localization.current }
        set {
            Localization.current = newValue
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    @MainActor
    static func setLanguage(_ newValue: AppLanguage) {
        Localization.current = newValue
        if let delegate = NSApp?.delegate as? AppDelegate {
            NSApp.mainMenu = MainMenu.build(delegate: delegate)
        }
        AboutWindowController.shared.refreshLanguage()
        ShortcutsWindowController.shared.refreshLanguage()
        SettingsWindowController.shared.refreshLanguage()
        UpdateWindowController.shared.refreshLanguage()
        HelpWindowController.shared.refreshLanguage()
        NotificationCenter.default.post(name: changed, object: nil)
    }

    static var fontSize: CGFloat { CGFloat(value(Key.fontSize) as Double) }
    static var fontName: String { value(Key.fontName) }
    static var tabWidth: Int { max(1, value(Key.tabWidth)) }
    static var indentWithTabs: Bool { value(Key.indentWithTabs) }
    static var wordWrap: Bool { value(Key.wordWrap) }
    static var showLineNumbers: Bool { value(Key.showLineNumbers) }
    static var highlightCurrentLine: Bool { value(Key.highlightCurrentLine) }
    static var autoIndent: Bool { value(Key.autoIndent) }
    static var hideMarkdownMarkup: Bool { value(Key.hideMarkdownMarkup) }
    static var defaultEncoding: String.Encoding {
        let raw: Int = value(Key.defaultEncoding)
        return raw > 0 ? String.Encoding(rawValue: UInt(raw)) : .utf8
    }
    static var defaultLineEnding: LineEnding { LineEnding(rawValue: value(Key.defaultLineEnding)) ?? .lf }
    static var showHiddenFiles: Bool {
        get { value(Key.showHiddenFiles) }
        set { store.set(newValue, forKey: Key.showHiddenFiles) }
    }
    static var autoCheckUpdates: Bool {
        get { value(Key.autoCheckUpdates) }
        set { store.set(newValue, forKey: Key.autoCheckUpdates) }
    }
    static var indentStyle: IndentStyle { IndentStyle(usesTabs: indentWithTabs, width: tabWidth) }

    static var editorFont: NSFont { Theme.editorFont(name: fontName, size: fontSize) }

    static func set(_ value: Any?, for key: String) {
        store.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

struct SettingsView: View {
    @State private var language: AppLanguage = Localization.current
    @AppStorage(Preferences.Key.fontSize) private var fontSize = 13.0
    @AppStorage(Preferences.Key.fontName) private var fontName = ""
    @AppStorage(Preferences.Key.tabWidth) private var tabWidth = 4
    @AppStorage(Preferences.Key.indentWithTabs) private var indentWithTabs = false
    @AppStorage(Preferences.Key.wordWrap) private var wordWrap = true
    @AppStorage(Preferences.Key.showLineNumbers) private var showLineNumbers = true
    @AppStorage(Preferences.Key.highlightCurrentLine) private var highlightCurrentLine = true
    @AppStorage(Preferences.Key.autoIndent) private var autoIndent = true
    @AppStorage(Preferences.Key.defaultEncoding) private var defaultEncoding = Int(String.Encoding.utf8.rawValue)
    @AppStorage(Preferences.Key.defaultLineEnding) private var defaultLineEnding = "LF"
    @AppStorage(Preferences.Key.showHiddenFiles) private var showHiddenFiles = false
    @AppStorage(Preferences.Key.hideMarkdownMarkup) private var hideMarkdownMarkup = false
    @AppStorage(Preferences.Key.autoCheckUpdates) private var autoCheckUpdates = true

    private static let monospacedFamilies: [String] = {
        let names = NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }
        return names.sorted()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(L("Langue", "Language")) {
                row(L("Langue", "Language")) {
                    Picker("", selection: $language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
            section(L("Texte", "Text")) {
                row(L("Police", "Font")) {
                    Picker("", selection: $fontName) {
                        Text(L("SF Mono (système)", "SF Mono (system)")).tag("")
                        ForEach(Self.monospacedFamilies, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                row(L("Taille", "Size")) {
                    Stepper(value: $fontSize, in: 8...48, step: 1) {
                        Text("\(Int(fontSize)) pt").monospacedDigit()
                    }
                }
                Toggle(L("Retour à la ligne automatique", "Word wrap"), isOn: $wordWrap)
                Toggle(L("Numéros de ligne", "Line numbers"), isOn: $showLineNumbers)
                Toggle(L("Surligner la ligne courante", "Highlight current line"), isOn: $highlightCurrentLine)
                Toggle(L("Masquer les balises Markdown, sauf sur la ligne du curseur", "Hide Markdown markup except on the caret line"), isOn: $hideMarkdownMarkup)
            }
            section(L("Indentation", "Indentation")) {
                Toggle(L("Indenter la nouvelle ligne comme la précédente", "Indent new lines like the previous line"), isOn: $autoIndent)
                row(L("Nouveaux fichiers", "New files")) {
                    Picker("", selection: $indentWithTabs) {
                        Text(L("Espaces", "Spaces")).tag(false)
                        Text(L("Tabulations", "Tabs")).tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                row(L("Largeur", "Width")) {
                    Stepper(value: $tabWidth, in: 1...16) {
                        Text(L("\(tabWidth) colonnes", "\(tabWidth) columns")).monospacedDigit()
                    }
                }
                Text(L("Un fichier ouvert garde l’indentation lue dans son texte.", "An opened file keeps the indentation detected in its text."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
            section(L("Fichiers", "Files")) {
                row(L("Encodage par défaut", "Default encoding")) {
                    Picker("", selection: $defaultEncoding) {
                        ForEach(SimpleTextCore.TextFile.encodings, id: \.rawValue) { encoding in
                            Text(SimpleTextCore.TextFile.name(of: encoding)).tag(Int(encoding.rawValue))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                row(L("Fins de ligne par défaut", "Default line endings")) {
                    Picker("", selection: $defaultLineEnding) {
                        ForEach(SimpleTextCore.LineEnding.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Toggle(L("Afficher les fichiers masqués dans le dialogue d’ouverture", "Show hidden files in the Open dialog"), isOn: $showHiddenFiles)
            }
            section(L("Mises à jour", "Updates")) {
                HStack(spacing: 12) {
                    Toggle(L("Vérifier les mises à jour au lancement", "Check for updates on launch"), isOn: $autoCheckUpdates)
                    Spacer(minLength: 8)
                    Button(L("Vérifier maintenant…", "Check Now…")) {
                        (NSApp.delegate as? AppDelegate)?.checkForUpdates(nil)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: language) { _, newValue in
            Preferences.setLanguage(newValue)
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.text.swiftUI)
        .padding(22)
        .frame(width: 460, alignment: .topLeading)
        .background(Theme.panel.swiftUI)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Theme.textFaint.swiftUI)
            content()
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label).foregroundStyle(Theme.textDim.swiftUI).frame(width: 150, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }
}
