import AppKit
import SimpleTextCore
import SwiftUI

struct AboutView: View {
    let close: () -> Void
    @State private var copiedVersion = false
    @AppStorage(Localization.defaultsKey) private var languageRaw = AppLanguage.system.rawValue

    private struct FeatureCard: Identifiable {
        let id: String
        let icon: String
        let tint: NSColor
        let title: String
        let detail: String
    }

    private var features: [FeatureCard] {
        [
            FeatureCard(
                id: "languages", icon: "chevron.left.forwardslash.chevron.right", tint: Theme.accent,
                title: L("Coloration par langage", "Syntax highlighting"),
                detail: L(
                    "C, Objective-C, C#, Swift, HTML, PHP, JavaScript, Python, Shell, JSON, YAML, CSS… choisis d’après l’extension, ou dans la barre d’état. Markdown mis en forme en écrivant.",
                    "C, Objective-C, C#, Swift, HTML, PHP, JavaScript, Python, Shell, JSON, YAML, CSS… chosen from the file extension or the status bar. Live-formatted Markdown as you type."
                )
            ),
            FeatureCard(
                id: "files", icon: "doc.text", tint: Theme.cyan,
                title: L("Tout fichier texte", "Any text file"),
                detail: L(
                    "Quelle que soit l’extension, RTF compris ; encodage et fins de ligne détectés et conservés, fichiers masqués dans le dialogue d’ouverture, onglets, versions.",
                    "Whatever the extension, including RTF; encoding and line endings detected and preserved, hidden files in the Open dialog, tabs, versions."
                )
            ),
            FeatureCard(
                id: "editing", icon: "text.alignleft", tint: Theme.green,
                title: L("Édition de code", "Code editing"),
                detail: L(
                    "Indentation automatique, lignes dupliquées ou déplacées, commentaires en une touche, recherche et remplacement, aller à la ligne, numéros de ligne.",
                    "Auto-indentation, duplicate or move lines, single-key comments, find and replace, go to line, line numbers."
                )
            ),
            FeatureCard(
                id: "native", icon: "bolt.fill", tint: Theme.blue,
                title: L("Natif et léger", "Native and lightweight"),
                detail: L(
                    "AppKit et TextKit 2, aucune dépendance, quelques mégaoctets, démarrage instantané. De la famille SimpleAudio et Simple Recorder.",
                    "AppKit and TextKit 2, zero dependencies, a few megabytes, instant launch. Part of the SimpleAudio and Simple Recorder family."
                )
            ),
        ]
    }

    var body: some View {
        let _ = languageRaw
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
                    Text(L("Éditeur de texte et de code natif, rapide et léger, pour macOS", "Native, fast and lightweight text and code editor for macOS"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textDim.swiftUI)
                    HStack(spacing: 8) {
                        pill(icon: "cpu", text: "AppKit · TextKit 2", tint: Theme.accent)
                        pill(icon: "swift", text: L("Swift, zéro dépendance", "Swift, zero dependencies"), tint: Theme.cyan)
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("CE QUE FAIT SIMPLETEXT", "WHAT SIMPLETEXT DOES"))
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textFaint.swiftUI)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(features) { item in
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
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://adrien-m.net")!)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Adrien Mondot · cie Adrien M")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textDim.swiftUI)
                            Text("· adrien-m.net ↗")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Theme.accent.swiftUI)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("https://adrien-m.net")
                    Text(L("Licence GPL v3+ · \(AppVersion.bundleIdentifier)", "GPL v3+ License · \(AppVersion.bundleIdentifier)"))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Theme.textFaint.swiftUI)
                }
                Spacer()
                Button {
                    close()
                    (NSApp.delegate as? AppDelegate)?.checkForUpdates(nil)
                } label: {
                    Label(L("Rechercher des mises à jour…", "Check for Updates…"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textDim.swiftUI)
                Button {
                    close()
                    HelpWindowController.shared.show()
                } label: {
                    Label(L("Aide (⌘?)", "Help (⌘?)"), systemImage: "book.closed")
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
                    Text(L("Copié", "Copied"))
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
        .help(L("Cliquer pour copier « \(AppVersion.description) » dans le presse-papiers", "Click to copy “\(AppVersion.description)” to the clipboard"))
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
    @AppStorage(Localization.defaultsKey) private var languageRaw = AppLanguage.system.rawValue

    static var groups: [(String, [(String, String)])] {
        [
            (L("Fichier", "File"), [
                ("⌘N", L("Nouveau document", "New document")),
                ("⌘O", L("Ouvrir… (fichiers masqués au choix)", "Open… (optional hidden files)")),
                ("⌘S", L("Enregistrer", "Save")),
                ("⇧⌘S", L("Dupliquer", "Duplicate")),
                ("⌥⇧⌘S", L("Enregistrer sous…", "Save As…")),
                ("⌘W", L("Fermer l’onglet ou la fenêtre", "Close tab or window")),
                ("⌘,", L("Réglages", "Settings")),
                ("⌃⌘F", L("Plein écran", "Full Screen")),
            ]),
            (L("Édition", "Edit"), [
                ("⌘Z / ⇧⌘Z", L("Annuler / Rétablir", "Undo / Redo")),
                ("⌘D", L("Dupliquer la ligne", "Duplicate line")),
                ("⇧⌘K", L("Supprimer la ligne", "Delete line")),
                ("⌥↑ / ⌥↓", L("Déplacer la ligne", "Move line")),
                ("⌘] / ⌘[", L("Indenter / Désindenter", "Indent / Outdent")),
                ("⇥ / ⇧⇥", L("Indenter / Désindenter la sélection", "Indent / Outdent selection")),
                ("⌥⌘/", L("Commenter / Décommenter", "Toggle comment")),
                ("↩", L("Nouvelle ligne indentée comme la précédente", "New line indented like the previous one")),
            ]),
            (L("Recherche & Présentation", "Find & View"), [
                ("⌘F", L("Rechercher", "Find")),
                ("⌥⌘F", L("Rechercher et remplacer", "Find and replace")),
                ("⌘G / ⇧⌘G", L("Occurrence suivante / précédente", "Next / previous match")),
                ("⌘E", L("Utiliser la sélection pour la recherche", "Use selection for find")),
                ("⌘L", L("Aller à la ligne…", "Go to line…")),
                ("⌥⌘W", L("Retour à la ligne automatique", "Word wrap")),
                ("⇧⌘L", L("Numéros de ligne", "Line numbers")),
                ("⌥⌘M", L("Masquer les balises Markdown", "Hide Markdown markup")),
                ("⌘+ / ⌘- / ⌘0", L("Taille du texte", "Text size")),
                ("⌘B / ⌘I / ⌘U", L("Gras / italique / souligné (RTF)", "Bold / italic / underline (RTF)")),
                ("⌘T / ⇧⌘C", L("Polices / couleurs (RTF)", "Fonts / colors (RTF)")),
                ("⌘? / ⌘/", L("Aide / Cette liste", "Help / This list")),
            ]),
        ]
    }

    var body: some View {
        let _ = languageRaw
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Raccourcis clavier", "Keyboard Shortcuts"))
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
                Text(L("Les menus Fichier, Édition et Présentation listent tout.", "The File, Edit and View menus list every command."))
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

struct UpdateView: View {
    let close: () -> Void
    var updater = SimpleUpdater.shared
    @AppStorage(Localization.defaultsKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(SimpleUpdater.autoCheckKey) private var autoCheck = true

    var body: some View {
        let _ = languageRaw
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: AppVersion.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("SimpleText")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.text.swiftUI)
                        Text(AppVersion.shortLabel)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.textDim.swiftUI)
                    }
                    statusLine
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.separator.swiftUI).frame(height: 1)

            if let release = activeRelease {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L("NOTES DE VERSION — \(release.displayVersion)", "RELEASE NOTES — \(release.displayVersion)"))
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(0.8)
                            .foregroundStyle(Theme.textFaint.swiftUI)
                        Spacer()
                        if let htmlURL = release.htmlURL {
                            Button(L("Voir sur GitHub ↗", "View on GitHub ↗")) {
                                NSWorkspace.shared.open(htmlURL)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.cyan.swiftUI)
                        }
                    }
                    ScrollView {
                        Text(release.localizedNotes)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textDim.swiftUI)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .frame(height: 130)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.lane.swiftUI))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Toggle(L("Vérifier les mises à jour au lancement", "Check for updates on launch"), isOn: $autoCheck)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim.swiftUI)

                Spacer()

                actionButtons
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(Theme.panel.swiftUI)
    }

    private var activeRelease: SimpleUpdater.ReleaseInfo? {
        switch updater.state {
        case .updateAvailable(let r), .downloading(let r), .installing(let r):
            return r
        default:
            return updater.availableRelease
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch updater.state {
        case .idle, .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("Recherche de mises à jour…", "Checking for updates…"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim.swiftUI)
            }
        case .upToDate(let current):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.green.swiftUI)
                Text(L("SimpleText est à jour (v\(current)).", "SimpleText is up to date (v\(current))."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text.swiftUI)
            }
        case .updateAvailable(let release):
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(Theme.accent.swiftUI)
                Text(L("Nouvelle version disponible : v\(release.version)", "New version available: v\(release.version)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent.swiftUI)
            }
        case .downloading(let release):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("Téléchargement de v\(release.version)…", "Downloading v\(release.version)…"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim.swiftUI)
            }
        case .installing(let release):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("Vérification et installation de v\(release.version)…", "Verifying and installing v\(release.version)…"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim.swiftUI)
            }
        case .error(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.red.swiftUI)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.red.swiftUI)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch updater.state {
        case .updateAvailable(let release):
            Button(L("Plus tard", "Later"), action: close)
            Button(L("Mettre à jour et relancer", "Update & Relaunch")) {
                Task { await updater.downloadAndInstall(release) }
            }
            .keyboardShortcut(.defaultAction)
        case .downloading, .installing:
            Button(L("Fermer", "Close"), action: close)
                .disabled(true)
        case .error:
            Button(L("Réessayer", "Retry")) {
                Task { await updater.checkForUpdates(userInitiated: true) }
            }
            Button("OK", action: close)
                .keyboardShortcut(.defaultAction)
        default:
            Button("OK", action: close)
                .keyboardShortcut(.defaultAction)
        }
    }
}
