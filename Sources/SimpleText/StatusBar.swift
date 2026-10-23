import SwiftUI
import SimpleTextCore

/// The bar under the text: language, caret, selection, counts, encoding, line endings, indentation,
/// then help, shortcuts and the version, as in SimpleAudio.
struct StatusBar: View {
    var model: EditorModel
    let actions: StatusBarActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            if model.isRichText {
                pill("RTF", tint: Theme.accent)
                    .help("Texte enrichi : polices et couleurs du fichier")
            } else {
                Menu {
                    ForEach(Language.all) { language in
                        Button(language.name) { actions.pickLanguage(language.name) }
                    }
                } label: {
                    pill(model.languageName, tint: Theme.accent)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Langage de coloration de ce document")
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
                Text("sans coloration")
                    .foregroundStyle(Theme.textFaint.swiftUI)
                    .help("Au-delà de 4 Mo le texte n’est pas colorié")
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
            .help("Encodage du fichier ; un document non modifié est relu dans l’encodage choisi")

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
            .help("Fins de ligne écrites à l’enregistrement")

            Text(model.indentLabel)
                .foregroundStyle(Theme.textDim.swiftUI)
                .help("Indentation lue dans le fichier")
            }

            divider

            HStack(spacing: 12) {
                statusButton("? aide", help: "Ouvrir le guide de SimpleText (⌘?)", action: actions.showHelp)
                statusButton("⌘/ raccourcis", help: "Afficher les raccourcis clavier (⌘/)", action: actions.showShortcuts)
                statusButton(AppVersion.shortLabel, help: "À propos de \(AppVersion.description)", action: actions.showAbout)
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
        let characters = model.selectedCharacters == 1 ? "1 caractère" : "\(model.selectedCharacters) caractères"
        return model.selectedLines > 1 ? "\(characters) · \(model.selectedLines) lignes" : characters
    }

    private var countsText: String {
        let lines = model.lines == 1 ? "1 ligne" : "\(model.lines) lignes"
        guard let words = model.words else { return lines }
        return "\(lines) · \(words == 1 ? "1 mot" : "\(words) mots")"
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
