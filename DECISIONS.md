# DECISIONS

Journal des choix structurants. Chaque entrée : le choix, pourquoi, et ce qu'on a écarté. D1 a été tranchée par Adrien le 23 octobre 2026 ; les suivantes ont été prises en autonomie et sont réversibles.

## Cadrage

- **D1 — SimpleText est une application native Swift/AppKit, dans un dépôt neuf, sans aucune dépendance.** Adrien a d'abord demandé de transformer MarkText en SimpleText, puis l'a arrêté net en découvrant que MarkText est une application Electron (« je déteste Electron » ; l'app empaquetée pesait 412 Mo). Le travail Electron reste sur la branche `simpletext` du dépôt `marktext`, non poussé. Modèle : SimpleAudio et Simple Recorder.
- **D2 — Paquet SwiftPM, pas de projet Xcode, `swiftLanguageModes: [.v5]`, macOS 14 minimum.** Comme SimpleAudio. Le mode Swift 6 strict ferait passer des heures sur l'isolation des délégués d'`NSDocument` et de `NSTextView` ; l'app n'a qu'un thread.
- **D3 — Document AppKit classique : `NSDocument` + `NSWindowController` + `NSTextView`, menu construit en code en français.** `NSDocument` donne les onglets, Ouvrir récent, Dupliquer, Renommer, Déplacer, les versions et la restauration au lancement. SwiftUI sert seulement aux feuilles (À propos, raccourcis, réglages) et à la barre d'état, dans des `NSHostingView`. Écarté : `DocumentGroup` de SwiftUI, qui ne laisse pas la main sur la vue texte.

## L'éditeur

- **D4 — TextKit 2** (`NSTextView(usingTextLayoutManager: true)`), le stockage du document branché sur `textContentStorage.textStorage` : un seul texte pour la lecture, l'éditeur, les retours en arrière et l'enregistrement. **Ne jamais lire `textView.layoutManager`** : l'accès seul rétrograde la vue en TextKit 1 (constaté le 23 octobre avec une simple sonde de débogage) ; un test vérifie que `textLayoutManager` reste non nul.
- **D5 — Gouttière maison, pas d'`NSRulerView`.** Constaté le 23 octobre sur macOS 15 : une règle verticale sur la `NSScrollView` décale les `bounds` de la vue de clip de l'épaisseur de la règle et la vue texte n'est plus dessinée du tout (aucun pixel, ni en TextKit 2 ni en TextKit 1). La gouttière est une vue sœur à gauche de la zone de défilement, redessinée quand la vue de clip défile ; elle lit les fragments de mise en page de TextKit 2 pour placer chaque numéro sur sa ligne de base.
- **D6 — Toutes les fonctions « intelligentes » d'AppKit sont coupées** (guillemets et tirets typographiques, remplacement de texte, correction, détection de liens et de données, texte riche, panneau des polices) dans une seule fonction, relue par un test : une seule oubliée change `"` en `“` dans un fichier Swift.
- **D7 — Enregistrement automatique sur place** (`autosavesInPlace`), comme TextEdit : versions, « Modifié » dans la barre de titre, pas de question à la fermeture d'un fichier qui a un nom. Les modifications d'attributs faites par la coloration ne passent pas par le gestionnaire d'annulation : elles ne salissent jamais le document (test).
- **D8 — Tout fichier texte s'ouvre, quelle que soit son extension ou sans extension.** `DocumentController.typeForContents` renvoie un seul type après avoir vérifié l'absence d'octet nul dans les 8 premiers Ko ; un fichier binaire est refusé avec un message. `.h` est lu comme Objective-C (ses règles couvrent le C ; eMotion et Simple Recorder sont en Objective-C) ; le langage d'un document se change dans la barre d'état ou le menu Présentation.
- **D9 — Encodage et fins de ligne.** Marque d'ordre des octets, puis UTF-8, puis l'encodage par défaut des réglages, puis la détection de Foundation (`NSString.stringEncoding(for:…)`), puis Latin 1. CR et CRLF sont normalisés en LF en mémoire, l'original est restitué à l'écriture (test octet pour octet). Changer l'encodage d'un document propre le relit depuis le disque ; d'un document modifié, ne change que l'écriture.
- **D10 — Indentation lue dans le fichier** (tabulations, sinon le plus petit retrait rencontré : 2, 3, 4 ou 8 espaces), les réglages ne servant qu'aux nouveaux documents. La touche ⇥ complète jusqu'à la colonne suivante ; ↩ reprend le retrait de la ligne et en ajoute un après `{`, `(` ou `[`, et place le curseur entre les accolades quand la fermante suit.
- **D11 — Coloration par des lexers maison dans `SimpleTextCore`**, pilotés par des tables (mots-clés, commentaires, chaînes, nombres, préprocesseur, annotations) ; Markdown et HTML (avec PHP, JS et CSS imbriqués) ont leur propre code. Couleur seulement, jamais de gras ni d'italique (sauf Markdown, D20) : la mise en page ne bouge pas quand un mot change de rôle. Au-delà de 4 Mo le texte n'est pas colorié (la barre d'état le dit). Écarté : tree-sitter ou toute bibliothèque (D1).

## L'interface

- **D12 — Palette de SimpleAudio, sombre seulement** (`Theme.swift` copié), barre d'état de SimpleAudio (langage, caret, sélection, comptes, encodage, fins de ligne, indentation, `? aide`, `⌘/ raccourcis`, version), fenêtre À propos et guide d'aide HTML de Simple Recorder, feuille des raccourcis de SimpleAudio.
- **D13 — Panneau d'ouverture** : `beginOpenPanel(_:forTypes:completionHandler:)` surchargé, tous les types permis, et une case « Afficher les fichiers masqués » dans le panneau, liée en direct à `showsHiddenFiles` et mémorisée dans les réglages (demande d'Adrien).
- **D14 — Fichier ▸ Ouvrir l'élément récent est celui d'AppKit.** Dès que l'`Info.plist` déclare des types de documents, AppKit insère lui-même ce sous-menu après « Ouvrir… » (et « Partager » en fin de menu) ; le sous-menu construit à la main de la 0.9.0 apparaissait donc en double dans l'app empaquetée, jamais en debug. Écarté : le garder en le nommant par le sélecteur privé `_setMenuName:`.
- **D15 — Interface en français**, chaînes en dur (un seul utilisateur) ; un `fr.lproj` vide dans le bundle pour qu'AppKit lui-même parle français (« Sans titre », panneaux).
- **D16 — Vérifier sans l'écran** : `SimpleText --snapshot sortie.png [fichier]` ouvre le fichier et photographie la fenêtre par le serveur de fenêtres (`CGWindowListCreateImage`) ; `cacheDisplay` ne rend pas le contenu des couches de TextKit 2 (constaté le 23 octobre).

## Identité et livraison

- **D17 — Identifiant `net.cieadrienm.simpletext`**, version **0.9.0** dans `Scripts/bundle.sh` seulement (correctif : x.y.Z ; fonction : x.Y.0), ligne dans `CHANGELOG.md`, tag `vX.Y.Z` quand Adrien déploie. `Scripts/bundle.sh` construit et signe `build/SimpleText.app` ; `INSTALL=1` le copie dans /Applications.
- **D18 — L'icône est dessinée par un script** (`Scripts/make-icon.swift`) : la tuile sombre de la famille, cinq lignes de code ambre et cyan, le curseur rouge de la tête de lecture de SimpleAudio.
- **D19 — Commits par phase, jamais de push** sans Adrien ; `swift build` et `swift test` verts à chaque commit.

## Markdown

- **D20 — Le Markdown est mis en forme dans la source, le balisage reste visible** (24 octobre 2026, à la demande d'Adrien : « affiché et édité interprété »). Le surligneur, pour le seul lexer qui déclare `usesFonts`, change aussi les polices : titres en gras et plus grands (×1,4, ×1,25, ×1,1, puis gras seul), gras, italique (la face italique de la police, sinon une pente), barré `~~…~~`, liens soulignés, code en ligne sur une tuile, puces en gras ; les marqueurs (`#`, `**`, `*`, `` ` ``, `~~`) sont estompés pour que les mots ressortent. Même police que le reste de l'éditeur, donc les tableaux et le code restent alignés. Chaque ligne repart d'une police nue avant ses jetons, et quitter Markdown remet tout en une seule police (tests). Écarté : un WYSIWYG qui cache le balisage (c'est MarkText, une autre application) et un aperçu rendu à part (le texte ne serait plus édité « interprété »).

## Remis à plus tard

- Barre latérale de dossier et recherche dans un projet.
- Pilotage OSC / MCP comme SimpleAudio : rien à piloter dans un éditeur de texte.
- Thème clair.
- Markdown : aperçu rendu à part, tableaux alignés, images, liens cliquables, cases à cocher par clic, pliage.
- Complétion de mots, pliage de code, mini-carte.

## Constaté

- MarkText 0.24 (Electron), la référence écartée : 412 Mo empaqueté, 6,8 Mo de JavaScript dans le renderer.
- SimpleText 0.9.0, 23 octobre 2026 : `build/SimpleText.app` **3,0 Mo** (binaire universel arm64 + x86_64 de 2,5 Mo), signé Apple Development ; du lancement du binaire empaqueté à la capture d'un fichier Swift ouvert, **0,67 s** (`--snapshot`, délai 50 ms). En release, 1 Mo de Swift (36 000 lignes) se lexe en 44 ms et se colore en 226 ms ; un journal de 3,2 Mo (40 000 lignes) s'ouvre et se parcourt sans attente.
- 36 tests (`swift test`, ~2 s) : fichiers texte et encodages, index de lignes, indentation, langages, lexers (Swift, Objective-C, C, C#, HTML, PHP, Markdown, et les courants), document, éditeur, coloration incrémentale, mise en forme du Markdown, panneau d'ouverture, réinterprétation d'encodage.
- Un `NSOpenPanel` ne se retient pas depuis Swift : référence faible (plantage `swift_unknownObjectWeakAssign`) comme référence forte (pointeur pendant à l'affectation suivante, toutes les instances de `DocumentController` étant le singleton d'`NSDocumentController`). La case « fichiers masqués » vit donc dans une vue accessoire que le panneau possède, avec un `unowned(unsafe)` vers lui.
- `flush()` du surligneur bouclait sans fin sur un document sans lexer : la plage sale est vidée quand il n'y a rien à colorer (test).
- Les menus ne se photographient pas : `SIMPLETEXT_SNAPSHOT_MENU=Fichier` ouvre le menu un instant et liste ses éléments. C'est ainsi que le double « Ouvrir l'élément récent » a été vu dans le binaire empaqueté (23 octobre 2026) et pas dans le debug, qui n'a pas d'`Info.plist`.
