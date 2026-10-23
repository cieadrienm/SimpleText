import AppKit
import SimpleTextCore
import SwiftUI

struct AboutView: View {
    let close: () -> Void
    @State private var copiedVersion = false

    private struct FeatureCard: Identifiable {
        let id: String
        let icon: String
        let tint: NSColor
        let title: String
        let detail: String
    }

    private static let features: [FeatureCard] = [
        FeatureCard(
            id: "languages", icon: "chevron.left.forwardslash.chevron.right", tint: Theme.accent,
            title: "Coloration par langage",
            detail: "C, Objective-C, C#, Swift, HTML, PHP, JavaScript, Python, Shell, JSON, YAML, CSS… choisis d’après l’extension, ou dans la barre d’état. Markdown mis en forme en écrivant."
        ),
        FeatureCard(
            id: "files", icon: "doc.text", tint: Theme.cyan,
            title: "Tout fichier texte",
            detail: "Quelle que soit l’extension ; encodage et fins de ligne détectés et conservés, fichiers masqués dans le dialogue d’ouverture, onglets, versions."
        ),
        FeatureCard(
            id: "editing", icon: "text.alignleft", tint: Theme.green,
            title: "Édition de code",
            detail: "Indentation automatique, lignes dupliquées ou déplacées, commentaires en une touche, recherche et remplacement, aller à la ligne, numéros de ligne."
        ),
        FeatureCard(
            id: "native", icon: "bolt.fill", tint: Theme.blue,
            title: "Natif et léger",
            detail: "AppKit et TextKit 2, aucune dépendance, quelques mégaoctets, démarrage instantané. De la famille SimpleAudio et Simple Recorder."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                appIcon
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("SimpleText")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        versionBadge
                    }
                    Text("Éditeur de texte et de code natif, rapide et léger, pour macOS")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    HStack(spacing: 8) {
                        pill(icon: "cpu", text: "AppKit · TextKit 2", tint: Theme.accent)
                        pill(icon: "swift", text: "Swift, zéro dépendance", tint: Theme.cyan)
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("CE QUE FAIT SIMPLETEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textFaint.swiftUI)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Self.features) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.tint.swiftUI)
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.swiftUI.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Theme.text.swiftUI)
                                Text(item.detail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.lane.swiftUI))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adrien Mondot · cie Adrien M")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    Text("Licence MIT · \(AppVersion.bundleIdentifier)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Theme.textFaint.swiftUI)
                }
                Spacer()
                Button {
                    close()
                    HelpWindowController.shared.show()
                } label: {
                    Label("Aide (⌘?)", systemImage: "book.closed")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textDim.swiftUI)
                Button("OK", action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 580)
        .background(Theme.panel.swiftUI)
    }

    private var appIcon: some View {
        Image(nsImage: AppVersion.icon)
            .resizable()
            .interpolation(.high)
            .frame(width: 68, height: 68)
            .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
    }

    private var versionBadge: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(AppVersion.description, forType: .string)
            withAnimation(.easeOut(duration: 0.15)) { copiedVersion = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.2)) { copiedVersion = false }
            }
        } label: {
            HStack(spacing: 5) {
                Text(AppVersion.shortLabel)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.accent.swiftUI)
                Image(systemName: copiedVersion ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle((copiedVersion ? Theme.green : Theme.textFaint).swiftUI)
                if copiedVersion {
                    Text("Copié")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.green.swiftUI)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.accent.swiftUI.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Theme.accent.swiftUI.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Cliquer pour copier « \(AppVersion.description) » dans le presse-papiers")
    }

    private func pill(icon: String, text: String, tint: NSColor) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint.swiftUI)
            Text(text)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(Theme.textDim.swiftUI)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.lane.swiftUI))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct ShortcutsView: View {
    let close: () -> Void

    static let groups: [(String, [(String, String)])] = [
        ("Fichier", [
            ("⌘N", "Nouveau document"),
            ("⌘O", "Ouvrir… (fichiers masqués au choix)"),
            ("⌘S", "Enregistrer"),
            ("⇧⌘S", "Dupliquer"),
            ("⌥⇧⌘S", "Enregistrer sous…"),
            ("⌘W", "Fermer l’onglet ou la fenêtre"),
            ("⌘,", "Réglages"),
            ("⌃⌘F", "Plein écran"),
        ]),
        ("Édition", [
            ("⌘Z / ⇧⌘Z", "Annuler / Rétablir"),
            ("⌘D", "Dupliquer la ligne"),
            ("⇧⌘K", "Supprimer la ligne"),
            ("⌥↑ / ⌥↓", "Déplacer la ligne"),
            ("⌘] / ⌘[", "Indenter / Désindenter"),
            ("⇥ / ⇧⇥", "Indenter / Désindenter la sélection"),
            ("⌥⌘/", "Commenter / Décommenter"),
            ("↩", "Nouvelle ligne indentée comme la précédente"),
        ]),
        ("Recherche & Présentation", [
            ("⌘F", "Rechercher"),
            ("⌥⌘F", "Rechercher et remplacer"),
            ("⌘G / ⇧⌘G", "Occurrence suivante / précédente"),
            ("⌘E", "Utiliser la sélection pour la recherche"),
            ("⌘L", "Aller à la ligne…"),
            ("⌥⌘W", "Retour à la ligne automatique"),
            ("⇧⌘L", "Numéros de ligne"),
            ("⌥⌘M", "Masquer les balises Markdown"),
            ("⌘+ / ⌘- / ⌘0", "Taille du texte"),
            ("⌘? / ⌘/", "Aide / Cette liste"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Raccourcis clavier")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text.swiftUI)
                Spacer()
                Text(AppVersion.shortLabel)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
            HStack(alignment: .top, spacing: 24) {
                ForEach(Self.groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.0.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(Theme.textFaint.swiftUI)
                            .padding(.bottom, 2)
                        ForEach(group.1, id: \.0) { key, text in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(key)
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.accent.swiftUI)
                                    .frame(width: 104, alignment: .leading)
                                Text(text)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.textDim.swiftUI)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            HStack {
                Text("Les menus Fichier, Édition et Présentation listent tout.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint.swiftUI)
                Spacer()
                Button("OK", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 820)
        .background(Theme.panel.swiftUI)
    }
}

struct SettingsView: View {
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

    private static let monospacedFamilies: [String] = {
        let names = NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }
        return names.sorted()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Texte") {
                row("Police") {
                    Picker("", selection: $fontName) {
                        Text("SF Mono (système)").tag("")
                        ForEach(Self.monospacedFamilies, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                row("Taille") {
                    Stepper(value: $fontSize, in: 8...48, step: 1) {
                        Text("\(Int(fontSize)) pt").monospacedDigit()
                    }
                }
                Toggle("Retour à la ligne automatique", isOn: $wordWrap)
                Toggle("Numéros de ligne", isOn: $showLineNumbers)
                Toggle("Surligner la ligne courante", isOn: $highlightCurrentLine)
                Toggle("Masquer les balises Markdown, sauf sur la ligne du curseur", isOn: $hideMarkdownMarkup)
            }
            section("Indentation") {
                Toggle("Indenter la nouvelle ligne comme la précédente", isOn: $autoIndent)
                row("Nouveaux fichiers") {
                    Picker("", selection: $indentWithTabs) {
                        Text("Espaces").tag(false)
                        Text("Tabulations").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                row("Largeur") {
                    Stepper(value: $tabWidth, in: 1...16) {
                        Text("\(tabWidth) colonnes").monospacedDigit()
                    }
                }
                Text("Un fichier ouvert garde l’indentation lue dans son texte.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint.swiftUI)
            }
            section("Fichiers") {
                row("Encodage par défaut") {
                    Picker("", selection: $defaultEncoding) {
                        ForEach(SimpleTextCore.TextFile.encodings, id: \.rawValue) { encoding in
                            Text(SimpleTextCore.TextFile.name(of: encoding)).tag(Int(encoding.rawValue))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                row("Fins de ligne par défaut") {
                    Picker("", selection: $defaultLineEnding) {
                        ForEach(SimpleTextCore.LineEnding.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Toggle("Afficher les fichiers masqués dans le dialogue d’ouverture", isOn: $showHiddenFiles)
            }
            Spacer(minLength: 0)
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
