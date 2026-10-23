import AppKit
import SimpleTextCore

/// The application menu, in French, built in code (no nib). Document and text actions reach the
/// responder chain: the text view, then the editor controller, then the document and the application.
enum MainMenu {
    static func build(delegate: AppDelegate) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(applicationMenu(delegate))
        menu.addItem(fileMenu(delegate))
        menu.addItem(editMenu())
        menu.addItem(viewMenu())
        menu.addItem(windowMenu())
        menu.addItem(helpMenu(delegate))
        return menu
    }

    private static func applicationMenu(_ delegate: AppDelegate) -> NSMenuItem {
        let menu = NSMenu(title: AppVersion.name)
        menu.add("À propos de SimpleText", #selector(AppDelegate.showAbout(_:)), target: delegate)
        menu.addItem(.separator())
        menu.add("Réglages…", #selector(AppDelegate.showSettings(_:)), key: ",", target: delegate)
        menu.addItem(.separator())
        let services = NSMenu(title: "Services")
        NSApp.servicesMenu = services
        menu.add("Services", nil).submenu = services
        menu.addItem(.separator())
        menu.add("Masquer SimpleText", #selector(NSApplication.hide(_:)), key: "h")
        menu.add("Masquer les autres", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option])
        menu.add("Tout afficher", #selector(NSApplication.unhideAllApplications(_:)))
        menu.addItem(.separator())
        menu.add("Quitter SimpleText", #selector(NSApplication.terminate(_:)), key: "q")
        return menu.asItem()
    }

    private static func fileMenu(_ delegate: AppDelegate) -> NSMenuItem {
        let menu = NSMenu(title: "Fichier")
        menu.add("Nouveau", #selector(NSDocumentController.newDocument(_:)), key: "n")
        menu.add("Ouvrir…", #selector(NSDocumentController.openDocument(_:)), key: "o")
        let recent = NSMenu(title: "Ouvrir l’élément récent")
        recent.delegate = delegate
        menu.add("Ouvrir l’élément récent", nil).submenu = recent
        menu.addItem(.separator())
        menu.add("Fermer", #selector(NSWindow.performClose(_:)), key: "w")
        menu.add("Enregistrer", #selector(NSDocument.save(_:)), key: "s")
        menu.add("Dupliquer", #selector(NSDocument.duplicate(_:)), key: "s", modifiers: [.command, .shift])
        let saveAs = menu.add("Enregistrer sous…", #selector(NSDocument.saveAs(_:)), key: "s", modifiers: [.command, .shift, .option])
        saveAs.isAlternate = true
        menu.add("Renommer…", #selector(NSDocument.rename(_:)))
        menu.add("Déplacer vers…", #selector(NSDocument.move(_:)))
        let revert = NSMenu(title: "Revenir à")
        revert.add("Dernière version enregistrée", #selector(NSDocument.revertToSaved(_:)))
        revert.add("Parcourir toutes les versions…", #selector(NSDocument.browseVersions(_:)))
        menu.add("Revenir à", nil).submenu = revert
        return menu.asItem()
    }

    private static func editMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Édition")
        menu.add("Annuler", Selector(("undo:")), key: "z")
        menu.add("Rétablir", Selector(("redo:")), key: "z", modifiers: [.command, .shift])
        menu.addItem(.separator())
        menu.add("Couper", #selector(NSText.cut(_:)), key: "x")
        menu.add("Copier", #selector(NSText.copy(_:)), key: "c")
        menu.add("Coller", #selector(NSText.paste(_:)), key: "v")
        menu.add("Supprimer", #selector(NSText.delete(_:)))
        menu.add("Tout sélectionner", #selector(NSText.selectAll(_:)), key: "a")
        menu.addItem(.separator())
        menu.add("Dupliquer la ligne", #selector(EditorTextView.duplicateLine(_:)), key: "d")
        menu.add("Supprimer la ligne", #selector(EditorTextView.deleteLine(_:)), key: "k", modifiers: [.command, .shift])
        menu.add("Déplacer la ligne vers le haut", #selector(EditorTextView.moveLineUp(_:)), key: arrow(NSUpArrowFunctionKey), modifiers: [.option])
        menu.add("Déplacer la ligne vers le bas", #selector(EditorTextView.moveLineDown(_:)), key: arrow(NSDownArrowFunctionKey), modifiers: [.option])
        menu.addItem(.separator())
        menu.add("Indenter", #selector(EditorTextView.indentSelection(_:)), key: "]")
        menu.add("Désindenter", #selector(EditorTextView.outdentSelection(_:)), key: "[")
        menu.add("Commenter / Décommenter", #selector(EditorTextView.toggleComment(_:)), key: "/", modifiers: [.command, .option])
        menu.addItem(.separator())
        let find = NSMenu(title: "Rechercher")
        find.add("Rechercher…", #selector(NSTextView.performTextFinderAction(_:)), key: "f", tag: NSTextFinder.Action.showFindInterface.rawValue)
        find.add("Rechercher et remplacer…", #selector(NSTextView.performTextFinderAction(_:)), key: "f", modifiers: [.command, .option], tag: NSTextFinder.Action.showReplaceInterface.rawValue)
        find.add("Suivant", #selector(NSTextView.performTextFinderAction(_:)), key: "g", tag: NSTextFinder.Action.nextMatch.rawValue)
        find.add("Précédent", #selector(NSTextView.performTextFinderAction(_:)), key: "g", modifiers: [.command, .shift], tag: NSTextFinder.Action.previousMatch.rawValue)
        find.add("Utiliser la sélection pour la recherche", #selector(NSTextView.performTextFinderAction(_:)), key: "e", tag: NSTextFinder.Action.setSearchString.rawValue)
        find.addItem(.separator())
        find.add("Aller à la ligne…", #selector(EditorViewController.goToLine(_:)), key: "l")
        menu.add("Rechercher", nil).submenu = find
        let transform = NSMenu(title: "Transformations")
        transform.add("Majuscules", #selector(NSResponder.uppercaseWord(_:)))
        transform.add("Minuscules", #selector(NSResponder.lowercaseWord(_:)))
        transform.add("Capitales initiales", #selector(NSResponder.capitalizeWord(_:)))
        menu.add("Transformations", nil).submenu = transform
        return menu.asItem()
    }

    private static func viewMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Présentation")
        menu.add("Retour à la ligne automatique", #selector(EditorViewController.toggleWordWrap(_:)), key: "w", modifiers: [.command, .option])
        menu.add("Numéros de ligne", #selector(EditorViewController.toggleLineNumbers(_:)), key: "l", modifiers: [.command, .shift])
        menu.add("Surligner la ligne courante", #selector(EditorViewController.toggleCurrentLineHighlight(_:)))
        menu.addItem(.separator())
        menu.add("Agrandir le texte", #selector(EditorViewController.increaseFontSize(_:)), key: "+")
        let plus = menu.add("Agrandir le texte", #selector(EditorViewController.increaseFontSize(_:)), key: "=")
        plus.isAlternate = true
        plus.isHidden = true
        menu.add("Réduire le texte", #selector(EditorViewController.decreaseFontSize(_:)), key: "-")
        menu.add("Taille normale", #selector(EditorViewController.resetFontSize(_:)), key: "0")
        menu.addItem(.separator())
        let languages = NSMenu(title: "Langage")
        for language in Language.all {
            let item = languages.add(language.name, #selector(EditorViewController.setLanguage(_:)))
            item.representedObject = language.name
        }
        menu.add("Langage", nil).submenu = languages
        let encodings = NSMenu(title: "Encodage")
        for encoding in TextFile.encodings {
            let item = encodings.add(TextFile.name(of: encoding), #selector(EditorViewController.setEncoding(_:)))
            item.representedObject = NSNumber(value: encoding.rawValue)
        }
        menu.add("Encodage", nil).submenu = encodings
        let endings = NSMenu(title: "Fins de ligne")
        for ending in LineEnding.allCases {
            let item = endings.add(ending.label, #selector(EditorViewController.setLineEnding(_:)))
            item.representedObject = ending.rawValue
        }
        menu.add("Fins de ligne", nil).submenu = endings
        menu.addItem(.separator())
        menu.add("Activer le mode plein écran", #selector(NSWindow.toggleFullScreen(_:)), key: "f", modifiers: [.command, .control])
        return menu.asItem()
    }

    private static func windowMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Fenêtre")
        menu.add("Réduire", #selector(NSWindow.performMiniaturize(_:)), key: "m")
        menu.add("Zoom", #selector(NSWindow.performZoom(_:)))
        menu.addItem(.separator())
        menu.add("Tout ramener au premier plan", #selector(NSApplication.arrangeInFront(_:)))
        NSApp.windowsMenu = menu
        return menu.asItem()
    }

    private static func helpMenu(_ delegate: AppDelegate) -> NSMenuItem {
        let menu = NSMenu(title: "Aide")
        menu.add("Aide SimpleText", #selector(AppDelegate.showHelp(_:)), key: "?", target: delegate)
        menu.add("Raccourcis clavier", #selector(AppDelegate.showShortcuts(_:)), key: "/", target: delegate)
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
