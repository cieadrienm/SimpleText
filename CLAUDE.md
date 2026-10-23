# SimpleText — notes pour les agents

SimpleText est un éditeur de texte et de code natif pour macOS (Swift, AppKit, TextKit 2, zéro dépendance), de la famille des apps Simple de la cie Adrien M (SimpleAudio, Simple Recorder, OSCScore, Montage). Adrien (spectacle vivant, app eMotion) est l'unique utilisateur ; il parle français et refuse Electron.

## Lire d'abord
- `DECISIONS.md` — D1…, le pourquoi de chaque choix, et ce qui est remis à plus tard. **Ajouter une entrée pour tout choix structurant.**
- `docs/superpowers/specs/2026-10-23-simpletext-design.md` — le design et ses phases.
- `README.md` — fonctionnalités et raccourcis.

## Façon de travailler
- Répondre en français. Code, commentaires et commits en anglais, avec la ligne `Co-Authored-By` de l'harnais.
- Pas de remote pour l'instant ; aucun push sans Adrien. Un commit par phase, `swift build` et `swift test` verts.
- Version : `VERSION` dans `Scripts/bundle.sh`, changée là seulement (correctif : x.y.Z ; fonction : x.Y.0), avec une ligne dans `CHANGELOG.md` et un tag git `vX.Y.Z` quand Adrien déploie.
- Les décisions à prendre vont dans `.project-map/decisions.md` (question, options, défaut, date) ; sans réponse, continuer avec le défaut.

## Build et tests
```
swift build                                   # .build/debug/SimpleText
swift test                                    # SimpleTextCoreTests + SimpleTextAppTests
.build/debug/SimpleText --snapshot /tmp/s.png [fichier]   # photographie la fenêtre sans écran
SIMPLETEXT_SNAPSHOT_WINDOW=about|shortcuts|settings|help|open … --snapshot …   # une fenêtre annexe
SIMPLETEXT_SNAPSHOT_MENU=Fichier … --snapshot /dev/null [fichier]  # liste un menu (prend le focus 0,4 s)
Scripts/bundle.sh                             # build/SimpleText.app signée (universelle)
INSTALL=1 Scripts/bundle.sh                   # et la copie dans /Applications
swift Scripts/make-icon.swift                 # redessine Resources/icon.icns
```
`swift run SimpleText fichier.txt` ouvre un fichier ; sans bundle, la version affichée est « dev ».

## Règles qui ont coûté cher
- **Ne jamais lire `textView.layoutManager`** : l'accès rétrograde la vue en TextKit 1 sans un mot (D4). `textLayoutManager` est la seule porte.
- **Pas de sous-menu « Ouvrir l'élément récent » à la main** : AppKit l'insère lui-même dans l'app empaquetée (D14) ; le debug, sans `Info.plist`, ne le montre pas, et les menus se vérifient avec `SIMPLETEXT_SNAPSHOT_MENU`.
- **Pas d'`NSRulerView`** : avec une règle verticale la vue texte n'est plus dessinée du tout sur macOS 15 (D5). La gouttière est `LineNumberGutter`, une vue sœur.
- **`cacheDisplay` ne voit pas le texte de TextKit 2** : `--snapshot` passe par `CGWindowListCreateImage` (D16).
- **Le groupe d'annulation se ferme avec le tour de boucle** : dans un test, `RunLoop.main.run(until:)` avant de lire `isDocumentEdited`.
- **Les réglages ont un défaut en code** (`Preferences.value`) : sans `registerDefaults` les tests liraient 0 et `false`.
- **Ne jamais retenir un `NSOpenPanel`**, ni faible (plantage `swift_unknownObjectWeakAssign`) ni fort (pointeur pendant) : ce qui doit lui parler vit dans sa vue accessoire, avec `unowned(unsafe)`. Et `DocumentController()` renvoie toujours le singleton d'`NSDocumentController`.
- **`DispatchQueue.main.async` ne tourne pas sous `RunLoop.main.run` dans les tests** : ce qui doit s'exécuter « au prochain tour » passe par `RunLoop.main.perform`.
- **Les chronos se font en release** (`swift test -c release`) : le build debug est dix à vingt fois plus lent sur les boucles du lexer.
- **Un `kill` sur `$!` après un sous-shell `( … ) &` tue le sous-shell, pas l'app** : lancer la commande directement, et vérifier avec `pgrep -f .build/debug/SimpleText` qu'aucune instance ne traîne.
- **Ne jamais tuer les apps d'Adrien** (eMotion, OSCScore, SimpleAudio tournent souvent). Lancer ses propres instances et les tuer par PID.
- `timeout` n'existe pas sur macOS : surveiller un lancement avec une boucle `kill -0`.

## Architecture en une minute
- `Sources/SimpleTextCore/` — pur Swift, testable sans AppKit : `TextFile` (binaire, encodages, fins de ligne), `LineIndex` + `TextStatistics` + `IndentStyle`, `Language` (registre et extensions ; `.h` = Objective-C), les lexers.
- `Sources/SimpleText/` — AppKit : `App` (entrée), `AppDelegate` (lancement, fenêtres annexes), `MainMenu` (menu français), `DocumentController` (tout fichier texte, fichiers masqués), `TextDocument`, `EditorWindowController` (onglets), `EditorViewController` (vue texte, gouttière, barre d'état, actions Présentation), `EditorTextView` (fonctions intelligentes coupées, indentation, lignes, commentaires, glisser-déposer), `LineNumberGutter`, `StatusBar` + `EditorModel` (SwiftUI), `Windows` + `AboutView` (À propos, raccourcis, réglages, aide), `Preferences`, `Theme`, `Snapshot`.
- `Resources/` — `Info.plist` (gabarit `@VERSION@`), `icon.icns`, `Help/index.html`, `fr.lproj`.
- `Scripts/` — `bundle.sh`, `make-icon.swift`.

## Invariants
- Un document est son `NSTextStorage` : lecture, édition, retour en arrière et enregistrement passent tous par lui.
- Un fichier est réécrit avec l'encodage et les fins de ligne lus, sauf changement explicite dans la barre d'état.
- Le langage vient du nom du fichier ou du choix de l'utilisateur, jamais d'une analyse du contenu.
- La coloration ne change que des couleurs, et des polices pour le seul lexer qui déclare `usesFonts` (Markdown, D20) ; jamais le texte ni l'historique d'annulation. Chaque ligne repart de la police nue avant ses jetons.
- Tout nouveau comportement a un test ; un défaut corrigé a d'abord un test qui échoue.
