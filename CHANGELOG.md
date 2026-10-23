# Changelog

## 0.11.0 — 2026-10-23

- Présentation › Masquer les balises Markdown (`⌥⌘M`, aussi dans les réglages) : `#`, `**`, `*`, `~~`, `` ` ``, `[ ]`, `(url)` et `>` disparaissent de toutes les lignes sauf celle du curseur, où ils reviennent estompés pour éditer. Le fichier ne change pas.
- Un réglage booléen peut se passer en argument (`-hideMarkdownMarkup 1`), utile avec `--snapshot`.
- Texte enrichi : les fichiers RTF s'ouvrent avec leurs polices et couleurs, s'éditent (menu Format : gras `⌘B`, italique `⌘I`, souligné `⌘U`, alignement, polices `⌘T`, couleurs `⇧⌘C`) et s'enregistrent en RTF. Le noir s'affiche dans la couleur du thème et reste noir dans le fichier. Format › Convertir en texte enrichi ou brut, dans une copie pour un fichier déjà enregistré. RTFD (avec images) non pris en charge.

## 0.10.0 — 2026-10-23

- Markdown mis en forme pendant l'édition : titres plus grands, gras, italique, barré (`~~…~~`), liens soulignés, code en ligne sur une tuile, marqueurs estompés. Le balisage reste visible.
- Fichier › Ouvrir l'élément récent n'apparaît plus en double : c'est le menu d'AppKit qui sert.
- `SIMPLETEXT_SNAPSHOT_MENU=<menu>` liste un menu en mode `--snapshot`.

## 0.9.0 — 2026-10-23

Première version de SimpleText, native (Swift, AppKit, TextKit 2), sans aucune dépendance.

- Documents AppKit : onglets, Ouvrir récent, Dupliquer, Renommer, Déplacer, versions, restauration au lancement.
- Tout fichier texte s'ouvre, quelle que soit son extension ; les binaires sont refusés. Encodage et fins de ligne détectés et conservés, indentation lue dans le fichier.
- Panneau d'ouverture avec case « Afficher les fichiers masqués ».
- Éditeur de code : numéros de ligne, ligne courante, indentation automatique, lignes dupliquées, supprimées ou déplacées, commentaires en une touche, recherche et remplacement, aller à la ligne.
- Palette sombre de la famille Simple ; barre d'état ; À propos, réglages, raccourcis (⌘/), aide (⌘?).
- Coloration incrémentale par tranches, 1 Mo de Swift en 226 ms ; au-delà de 4 Mo le texte reste brut.
- Application universelle de 3,0 Mo, signée ; `--snapshot` pour vérifier sans écran.
