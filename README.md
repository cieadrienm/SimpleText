# SimpleText

Éditeur de texte et de code **natif** pour macOS (Swift, AppKit, TextKit 2, zéro dépendance), de la famille des apps **Simple** de la **cie Adrien M** (SimpleAudio, Simple Recorder). Une fenêtre sombre, un fichier, sa coloration, et rien d'autre.

## Fonctionnalités

- **Coloration de syntaxe par langage** : C, Objective-C (y compris `.h`), C#, Swift, HTML, PHP, Markdown, JavaScript, TypeScript, JSON, CSS, Python, Shell, YAML, XML, SQL, Go, Rust, Java, Lua, Ruby, Makefile… choisie d'après l'extension, changeable dans la barre d'état ou le menu Présentation.
- **Tout fichier texte s'ouvre**, quelle que soit son extension ou sans extension ; les binaires sont refusés. Encodage (UTF-8, UTF-16, Latin 1, Windows 1252, Mac OS Roman…) et fins de ligne (LF, CRLF, CR) détectés et conservés à l'identique ; indentation lue dans le fichier.
- **Édition de code** : numéros de ligne, ligne courante, retour à la ligne au choix, indentation automatique, `⇥`/`⇧⇥` sur une sélection, lignes dupliquées (`⌘D`), supprimées (`⇧⌘K`) ou déplacées (`⌥↑`/`⌥↓`), commentaires en une touche (`⌥⌘/`), recherche et remplacement (`⌘F`, `⌥⌘F`), aller à la ligne (`⌘L`).
- **Documents à la Mac** : onglets, Ouvrir l'élément récent, Dupliquer, Renommer, Déplacer, versions, enregistrement automatique, fenêtres restaurées au lancement, glisser-déposer de fichiers sur la fenêtre ou le Dock.
- **Dialogue d'ouverture** avec case « Afficher les fichiers masqués », mémorisée.
- **Interface** : palette sombre de la famille Simple, barre d'état (langage, ligne et colonne, sélection, lignes et mots, encodage, fins de ligne, indentation), fenêtre À propos, réglages (`⌘,`), raccourcis (`⌘/`), guide d'aide en français (`⌘?`).

## Raccourcis

| Raccourci | Action |
| --- | --- |
| `⌘N` / `⌘O` | Nouveau / Ouvrir… |
| `⌘S` / `⇧⌘S` / `⌥⇧⌘S` | Enregistrer / Dupliquer / Enregistrer sous… |
| `⌘W` | Fermer |
| `⌘D` / `⇧⌘K` | Dupliquer / supprimer la ligne |
| `⌥↑` / `⌥↓` | Déplacer la ligne |
| `⌘]` / `⌘[` | Indenter / désindenter |
| `⌥⌘/` | Commenter / décommenter |
| `⌘F` / `⌥⌘F` / `⌘G` | Rechercher / remplacer / suivant |
| `⌘L` | Aller à la ligne… |
| `⌥⌘W` / `⇧⌘L` | Retour à la ligne / numéros de ligne |
| `⌘+` / `⌘-` / `⌘0` | Taille du texte |
| `⌘/` / `⌘?` | Raccourcis / Aide |

## Compilation et installation

```bash
swift build && swift test            # compile et teste
swift run SimpleText fichier.swift   # lance l'app sur un fichier
Scripts/bundle.sh                    # build/SimpleText.app, universelle, signée
INSTALL=1 Scripts/bundle.sh          # et la copie dans /Applications
```

## Taille et vitesse

| | SimpleText 0.9.0 | MarkText 0.24 (Electron, écarté) |
| --- | --- | --- |
| Application macOS | **3,0 Mo** (universelle, arm64 + x86_64) | 412 Mo |
| Du lancement à la capture PNG d'un fichier Swift ouvert (`--snapshot`, délai 50 ms) | 0,67 s | non mesuré |
| Coloration d'1 Mo de Swift (36 000 lignes) | 226 ms, par tranches, sans bloquer | — |
| Dépendances | aucune | 48 paquets npm |

## Vérifier sans écran

```bash
.build/debug/SimpleText --snapshot /tmp/s.png Player.swift                 # la fenêtre d'édition
SIMPLETEXT_SNAPSHOT_WINDOW=about .build/debug/SimpleText --snapshot /tmp/a.png   # about, shortcuts, settings ou help
```

## Crédits

**Adrien Mondot · cie Adrien M** — identifiant `net.cieadrienm.simpletext`, licence MIT. Les choix sont dans `DECISIONS.md`, les notes pour les agents dans `CLAUDE.md`.
