import SwiftUI
import SimpleTextCore

/// The bar under the text: language, caret, selection, counts, encoding, line endings, indentation,
/// then help, shortcuts and the version, as in SimpleAudio.
struct StatusBar: View {
    var model: EditorModel
    let actions: StatusBarActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Localization.defaultsKey) private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        let _ = languageRaw
        HStack(spacing: 12) {
            if model.isRichText {
                pill("RTF", tint: Theme.accent)
                    .help(L("Texte enrichi : polices et couleurs du fichier", "Rich text: fonts and colors from the file"))
            } else {
                Menu {
                    ForEach(Language.all) { language in
                        Button(language.displayName) { actions.pickLanguage(language.name) }
                    }
                } label: {
                    pill(model.languageName, tint: Theme.accent)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L("Langage de coloration de ce document", "Syntax highlighting language for this document"))
            }

            Text("Ln \(model.line), Col \(model.column)")
                .foregroundStyle(Theme.textDim.swiftUI)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: model.line)

            if model.selectedCharacters > 0 {
                Text(selectionText)
                    .foregroundStyle(Theme.cyan.swiftUI)
                    .transition(.opacity)
            }

            Spacer(minLength: 8)

            Text(countsText)
                .foregroundStyle(Theme.textFaint.swiftUI)
                .lineLimit(1)

            if !model.highlighted {
                Text(L("sans coloration", "no highlighting"))
                    .foregroundStyle(Theme.textFaint.swiftUI)
                    .help(L("Au-delà de 4 Mo le texte n’est pas colorié", "Above 4 MB, text is not highlighted"))
            }

            if !model.isRichText {
                divider

                Menu {
                    ForEach(TextFile.encodings, id: \.rawValue) { encoding in
                        Button(TextFile.name(of: encoding)) { actions.pickEncoding(encoding.rawValue) }
                    }
                } label: {
                    Text(model.encodingName).foregroundStyle(Theme.textDim.swiftUI)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L("Encodage du fichier ; un document non modifié est relu dans l’encodage choisi", "File encoding; an unmodified document is reloaded in the chosen encoding"))

                Menu {
                    ForEach(LineEnding.allCases, id: \.rawValue) { ending in
                        Button(ending.label) { actions.pickLineEnding(ending.rawValue) }
                    }
                } label: {
                    Text(model.lineEndingName).foregroundStyle(Theme.textDim.swiftUI)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L("Fins de ligne écrites à l’enregistrement", "Line endings written when saving"))

                Text(model.indentLabel)
                    .foregroundStyle(Theme.textDim.swiftUI)
                    .help(L("Indentation lue dans le fichier", "Indentation detected in the file"))
            }

            divider

            HStack(spacing: 12) {
                if let release = SimpleUpdater.shared.availableRelease {
                    Button {
                        actions.showUpdate()
                    } label: {
                        pill("↑ v\(release.version)", tint: Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help(L("Mise à jour v\(release.version) disponible — cliquer pour installer", "Update v\(release.version) available — click to install"))
                }
                statusButton(L("? aide", "? help"), help: L("Ouvrir le guide de SimpleText (⌘?)", "Open the SimpleText guide (⌘?)"), action: actions.showHelp)
                statusButton(L("⌘/ raccourcis", "⌘/ shortcuts"), help: L("Afficher les raccourcis clavier (⌘/)", "Show keyboard shortcuts (⌘/)"), action: actions.showShortcuts)
                statusButton(AppVersion.shortLabel, help: L("À propos de \(AppVersion.description)", "About \(AppVersion.description)"), action: actions.showAbout)
            }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(Theme.textFaint.swiftUI)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(Theme.panel.swiftUI)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.selectedCharacters > 0)
    }

    private var selectionText: String {
        let characters = model.selectedCharacters == 1 ? L("1 caractère", "1 character") : L("\(model.selectedCharacters) caractères", "\(model.selectedCharacters) characters")
        return model.selectedLines > 1 ? L("\(characters) · \(model.selectedLines) lignes", "\(characters) · \(model.selectedLines) lines") : characters
    }

    private var countsText: String {
        let lines = model.lines == 1 ? L("1 ligne", "1 line") : L("\(model.lines) lignes", "\(model.lines) lines")
        guard let words = model.words else { return lines }
        return "\(lines) · \(words == 1 ? L("1 mot", "1 word") : L("\(words) mots", "\(words) words"))"
    }

    private var divider: some View {
        Rectangle().fill(Theme.textFaint.swiftUI.opacity(0.5)).frame(width: 1, height: 12)
    }

    private func pill(_ text: String, tint: NSColor) -> some View {
        Text(text)
            .foregroundStyle(tint.swiftUI)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.swiftUI.opacity(0.12)))
    }

    private func statusButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(StatusButtonStyle())
        .help(help)
    }
}

/// A flat text button that brightens under the pointer, briefly.
private struct StatusButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle((hovered || configuration.isPressed ? Theme.text : Theme.textFaint).swiftUI)
            .onHover { hovered = $0 }
            .animation(.easeOut(duration: 0.12), value: hovered)
    }
}
