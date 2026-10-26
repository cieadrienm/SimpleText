import AppKit
import SimpleTextCore

/// The application menu, in French or English, built in code (no nib). Document and text actions reach the
/// responder chain: the text view, then the editor controller, then the document and the application.
enum MainMenu {
    static func build(delegate: AppDelegate) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(applicationMenu(delegate))
        menu.addItem(fileMenu())
        menu.addItem(editMenu())
        menu.addItem(formatMenu())
        menu.addItem(viewMenu())
        menu.addItem(windowMenu())
        menu.addItem(helpMenu(delegate))
        return menu
    }

    private static func applicationMenu(_ delegate: AppDelegate) -> NSMenuItem {
        let menu = NSMenu(title: AppVersion.name)
        menu.add(L("À propos de SimpleText", "About SimpleText"), #selector(AppDelegate.showAbout(_:)), target: delegate)
        menu.add(L("Rechercher des mises à jour…", "Check for Updates…"), #selector(AppDelegate.checkForUpdates(_:)), target: delegate)
        menu.addItem(.separator())
        menu.add(L("Réglages…", "Settings…"), #selector(AppDelegate.showSettings(_:)), key: ",", target: delegate)
        menu.addItem(.separator())
        let services = NSMenu(title: "Services")
        NSApp.servicesMenu = services
        menu.add("Services", nil).submenu = services
        menu.addItem(.separator())
        menu.add(L("Masquer SimpleText", "Hide SimpleText"), #selector(NSApplication.hide(_:)), key: "h")
        menu.add(L("Masquer les autres", "Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option])
        menu.add(L("Tout afficher", "Show All"), #selector(NSApplication.unhideAllApplications(_:)))
        menu.addItem(.separator())
        menu.add(L("Quitter SimpleText", "Quit SimpleText"), #selector(NSApplication.terminate(_:)), key: "q")
        return menu.asItem()
    }

    /// AppKit inserts « Ouvrir l’élément récent » / « Open Recent » after « Ouvrir… » itself (and « Partager »
    /// at the end) once the bundle declares document types; a hand-built one would come out twice (D14).
    private static func fileMenu() -> NSMenuItem {
        let menu = NSMenu(title: L("Fichier", "File"))
        menu.add(L("Nouveau", "New"), #selector(NSDocumentController.newDocument(_:)), key: "n")
        menu.add(L("Ouvrir…", "Open…"), #selector(NSDocumentController.openDocument(_:)), key: "o")
        menu.addItem(.separator())
        menu.add(L("Fermer", "Close"), #selector(NSWindow.performClose(_:)), key: "w")
        menu.add(L("Enregistrer", "Save"), #selector(NSDocument.save(_:)), key: "s")
        menu.add(L("Dupliquer", "Duplicate"), #selector(NSDocument.duplicate(_:)), key: "s", modifiers: [.command, .shift])
        let saveAs = menu.add(L("Enregistrer sous…", "Save As…"), #selector(NSDocument.saveAs(_:)), key: "s", modifiers: [.command, .shift, .option])
        saveAs.isAlternate = true
        menu.add(L("Renommer…", "Rename…"), #selector(NSDocument.rename(_:)))
        menu.add(L("Déplacer vers…", "Move To…"), #selector(NSDocument.move(_:)))
        let revertTitle = L("Revenir à", "Revert To")
        let revert = NSMenu(title: revertTitle)
        revert.add(L("Dernière version enregistrée", "Last Saved Version"), #selector(NSDocument.revertToSaved(_:)))
        revert.add(L("Parcourir toutes les versions…", "Browse All Versions…"), #selector(NSDocument.browseVersions(_:)))
        menu.add(revertTitle, nil).submenu = revert
        return menu.asItem()
    }

    private static func editMenu() -> NSMenuItem {
        let menu = NSMenu(title: L("Édition", "Edit"))
        menu.add(L("Annuler", "Undo"), Selector(("undo:")), key: "z")
        menu.add(L("Rétablir", "Redo"), Selector(("redo:")), key: "z", modifiers: [.command, .shift])
        menu.addItem(.separator())
        menu.add(L("Couper", "Cut"), #selector(NSText.cut(_:)), key: "x")
        menu.add(L("Copier", "Copy"), #selector(NSText.copy(_:)), key: "c")
        menu.add(L("Coller", "Paste"), #selector(NSText.paste(_:)), key: "v")
        menu.add(L("Supprimer", "Delete"), #selector(NSText.delete(_:)))
        menu.add(L("Tout sélectionner", "Select All"), #selector(NSText.selectAll(_:)), key: "a")
        menu.addItem(.separator())
        menu.add(L("Dupliquer la ligne", "Duplicate Line"), #selector(EditorTextView.duplicateLine(_:)), key: "d")
        menu.add(L("Supprimer la ligne", "Delete Line"), #selector(EditorTextView.deleteLine(_:)), key: "k", modifiers: [.command, .shift])
        menu.add(L("Déplacer la ligne vers le haut", "Move Line Up"), #selector(EditorTextView.moveLineUp(_:)), key: arrow(NSUpArrowFunctionKey), modifiers: [.option])
        menu.add(L("Déplacer la ligne vers le bas", "Move Line Down"), #selector(EditorTextView.moveLineDown(_:)), key: arrow(NSDownArrowFunctionKey), modifiers: [.option])
        menu.addItem(.separator())
        menu.add(L("Indenter", "Indent"), #selector(EditorTextView.indentSelection(_:)), key: "]")
        menu.add(L("Désindenter", "Outdent"), #selector(EditorTextView.outdentSelection(_:)), key: "[")
        menu.add(L("Commenter / Décommenter", "Toggle Comment"), #selector(EditorTextView.toggleComment(_:)), key: "/", modifiers: [.command, .option])
        menu.addItem(.separator())
        let findTitle = L("Rechercher", "Find")
        let find = NSMenu(title: findTitle)
        find.add(L("Rechercher…", "Find…"), #selector(NSTextView.performTextFinderAction(_:)), key: "f", tag: NSTextFinder.Action.showFindInterface.rawValue)
        find.add(L("Rechercher et remplacer…", "Find and Replace…"), #selector(NSTextView.performTextFinderAction(_:)), key: "f", modifiers: [.command, .option], tag: NSTextFinder.Action.showReplaceInterface.rawValue)
        find.add(L("Suivant", "Find Next"), #selector(NSTextView.performTextFinderAction(_:)), key: "g", tag: NSTextFinder.Action.nextMatch.rawValue)
        find.add(L("Précédent", "Find Previous"), #selector(NSTextView.performTextFinderAction(_:)), key: "g", modifiers: [.command, .shift], tag: NSTextFinder.Action.previousMatch.rawValue)
        find.add(L("Utiliser la sélection pour la recherche", "Use Selection for Find"), #selector(NSTextView.performTextFinderAction(_:)), key: "e", tag: NSTextFinder.Action.setSearchString.rawValue)
        find.addItem(.separator())
        find.add(L("Aller à la ligne…", "Go to Line…"), #selector(EditorViewController.goToLine(_:)), key: "l")
        menu.add(findTitle, nil).submenu = find
        let transformTitle = L("Transformations", "Transformations")
        let transform = NSMenu(title: transformTitle)
        transform.add(L("Majuscules", "Make Upper Case"), #selector(NSResponder.uppercaseWord(_:)))
        transform.add(L("Minuscules", "Make Lower Case"), #selector(NSResponder.lowercaseWord(_:)))
        transform.add(L("Capitales initiales", "Capitalize"), #selector(NSResponder.capitalizeWord(_:)))
        menu.add(transformTitle, nil).submenu = transform
        return menu.asItem()
    }

    /// Rich text (RTF) only; the text view disables every item in plain text.
    private static func formatMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Format")
        let fontTitle = L("Police", "Font")
        let font = NSMenu(title: fontTitle)
        font.add(L("Gras", "Bold"), #selector(EditorTextView.toggleFontTrait(_:)), key: "b", tag: Int(NSFontTraitMask.boldFontMask.rawValue))
        font.add(L("Italique", "Italic"), #selector(EditorTextView.toggleFontTrait(_:)), key: "i", tag: Int(NSFontTraitMask.italicFontMask.rawValue))
        font.add(L("Souligné", "Underline"), #selector(NSText.underline(_:)), key: "u")
        font.addItem(.separator())
        font.add(L("Afficher les polices", "Show Fonts"), #selector(EditorTextView.showFontPanel(_:)), key: "t")
        menu.add(fontTitle, nil).submenu = font
        let textTitle = L("Texte", "Text")
        let text = NSMenu(title: textTitle)
        text.add(L("Aligner à gauche", "Align Left"), #selector(NSText.alignLeft(_:)), key: "{")
        text.add(L("Centrer", "Center"), #selector(NSText.alignCenter(_:)), key: "|")
        text.add(L("Aligner à droite", "Align Right"), #selector(NSText.alignRight(_:)), key: "}")
        text.add(L("Justifier", "Justify"), #selector(NSTextView.alignJustified(_:)))
        menu.add(textTitle, nil).submenu = text
        menu.add(L("Afficher les couleurs", "Show Colors"), #selector(EditorTextView.showColorPanel(_:)), key: "c", modifiers: [.command, .shift])
        menu.addItem(.separator())
        menu.add(L("Convertir en texte enrichi", "Make Rich Text"), #selector(EditorViewController.toggleRichText(_:)))
        return menu.asItem()
    }

    private static func viewMenu() -> NSMenuItem {
        let menu = NSMenu(title: L("Présentation", "View"))
        menu.add(L("Retour à la ligne automatique", "Word Wrap"), #selector(EditorViewController.toggleWordWrap(_:)), key: "w", modifiers: [.command, .option])
        menu.add(L("Numéros de ligne", "Line Numbers"), #selector(EditorViewController.toggleLineNumbers(_:)), key: "l", modifiers: [.command, .shift])
        menu.add(L("Surligner la ligne courante", "Highlight Current Line"), #selector(EditorViewController.toggleCurrentLineHighlight(_:)))
        menu.add(L("Masquer les balises Markdown", "Hide Markdown Markup"), #selector(EditorViewController.toggleMarkdownMarkup(_:)), key: "m", modifiers: [.command, .option])
        menu.addItem(.separator())
        menu.add(L("Agrandir le texte", "Bigger"), #selector(EditorViewController.increaseFontSize(_:)), key: "+")
        menu.add(L("Réduire le texte", "Smaller"), #selector(EditorViewController.decreaseFontSize(_:)), key: "-")
        menu.add(L("Taille normale", "Actual Size"), #selector(EditorViewController.resetFontSize(_:)), key: "0")
        menu.addItem(.separator())
        let languageTitle = L("Langage", "Language")
        let languages = NSMenu(title: languageTitle)
        for language in Language.all {
            let item = languages.add(language.displayName, #selector(EditorViewController.setLanguage(_:)))
            item.representedObject = language.name
        }
        menu.add(languageTitle, nil).submenu = languages
        let encodingTitle = L("Encodage", "Encoding")
        let encodings = NSMenu(title: encodingTitle)
        for encoding in TextFile.encodings {
            let item = encodings.add(TextFile.name(of: encoding), #selector(EditorViewController.setEncoding(_:)))
            item.representedObject = NSNumber(value: encoding.rawValue)
        }
        menu.add(encodingTitle, nil).submenu = encodings
        let endingsTitle = L("Fins de ligne", "Line Endings")
        let endings = NSMenu(title: endingsTitle)
        for ending in LineEnding.allCases {
            let item = endings.add(ending.label, #selector(EditorViewController.setLineEnding(_:)))
            item.representedObject = ending.rawValue
        }
        menu.add(endingsTitle, nil).submenu = endings
        // AppKit appends « Activer le mode plein écran » (⌃⌘F) and the tab bar items itself (D14).
        return menu.asItem()
    }

    private static func windowMenu() -> NSMenuItem {
        let menu = NSMenu(title: L("Fenêtre", "Window"))
        menu.add(L("Réduire", "Minimize"), #selector(NSWindow.performMiniaturize(_:)), key: "m")
        menu.add("Zoom", #selector(NSWindow.performZoom(_:)))
        menu.addItem(.separator())
        menu.add(L("Tout ramener au premier plan", "Bring All to Front"), #selector(NSApplication.arrangeInFront(_:)))
        NSApp.windowsMenu = menu
        return menu.asItem()
    }

    private static func helpMenu(_ delegate: AppDelegate) -> NSMenuItem {
        let menu = NSMenu(title: L("Aide", "Help"))
        menu.add(L("Aide SimpleText", "SimpleText Help"), #selector(AppDelegate.showHelp(_:)), key: "?", target: delegate)
        menu.add(L("Raccourcis clavier", "Keyboard Shortcuts"), #selector(AppDelegate.showShortcuts(_:)), key: "/", target: delegate)
        menu.addItem(.separator())
        menu.add(L("Site web Simple Apps (adrien-m.net/software)", "Simple Apps Website (adrien-m.net/software)"), #selector(AppDelegate.openSimpleAppsWebsite(_:)), target: delegate)
        NSApp.helpMenu = menu
        return menu.asItem()
    }

    private static func arrow(_ code: Int) -> String {
        String(utf16CodeUnits: [unichar(code)], count: 1)
    }
}

extension NSMenu {
    @discardableResult
    func add(
        _ title: String,
        _ action: Selector?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        tag: Int = 0,
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        item.tag = tag
        item.target = target
        addItem(item)
        return item
    }

    func asItem() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = self
        return item
    }
}
