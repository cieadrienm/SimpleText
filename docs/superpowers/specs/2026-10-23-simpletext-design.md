# SimpleText — design

Date : 2026-10-23. Direction donnée par Adrien en conversation : « repars sur un SimpleText natif en Swift/AppKit
dans un nouveau dépôt, sur le modèle de SimpleAudio et Simple Recorder (mêmes règles d'interface, coloration
C, Objective-C, C#, HTML, PHP, Markdown, Swift et langages courants) ». Il avait d'abord demandé de transformer
MarkText, puis l'a arrêté en découvrant qu'il s'agissait d'Electron.

## But

Un éditeur de texte et de code **rapide et léger** : quelques mégaoctets, démarrage instantané, une fenêtre
sombre dans la palette de la famille Simple, qui ouvre n'importe quel fichier texte et le colore selon son
langage. Pas un IDE : pas d'arborescence de projet, pas de terminal, pas d'extensions.

## Ce qu'Adrien a décidé

- Natif Swift/AppKit, dépôt neuf `~/Programmation/SimpleText`, zéro Electron.
- Mêmes règles d'interface que SimpleAudio et Simple Recorder.
- Coloration : C, Objective-C, C#, HTML, PHP, Markdown, Swift et les langages courants.
- Option pour voir les fichiers masqués dans le dialogue d'ouverture.
- Le menu Fichier ▸ Ouvrir récent.

## Décisions prises pour lui

Voir `DECISIONS.md` (D2 à D19) : SwiftPM sans Xcode, `NSDocument` + `NSTextView` TextKit 2, gouttière
maison, fonctions « intelligentes » coupées, autosave sur place, tout fichier texte accepté après un test
d'octet nul, `.h` = Objective-C, lexers maison dans un cœur testable, couleur seulement, 4 Mo au-delà
desquels on ne colore plus, interface en français, `--snapshot` pour vérifier sans écran.

## La fenêtre

```
┌ ● ● ●           📄 Player.swift ▾                                              ┐  barre de titre native
│  1 │ import AVFoundation                                                       │  (icône du document,
│  2 │                                                                           │   onglets natifs)
│  3 │ /// Plays a clip from the timeline.                                       │
│  4 │ final class Player {                                                      │
│  5 │     private let engine = AVAudioEngine()                                  │
│ …  │                                                                           │
├────┴───────────────────────────────────────────────────────────────────────────┤
│ Swift   Ln 5, Col 12 · 3 caractères   14 lignes · 50 mots │ UTF-8  LF  Espaces : 4 │ ? aide  ⌘/ raccourcis  v0.9.0 │
└────────────────────────────────────────────────────────────────────────────────┘
```

Gouttière à gauche (numéros, ligne courante), texte en SF Mono 13, caret ambre, sélection cyan translucide.
Barre d'état de 26 points : à gauche le langage (menu), le caret et la sélection ; à droite les comptes,
l'encodage (menu), les fins de ligne (menu), l'indentation, puis `? aide`, `⌘/ raccourcis` et la version
(clic → À propos).

## Les parties

1. **Cœur** (`SimpleTextCore`, sans AppKit) : fichiers texte (binaire, encodages, fins de ligne), index de
   lignes, statistiques, indentation, registre des langages, lexers.
2. **App** : document, fenêtre et onglets, éditeur (vue texte, gouttière, barre d'état), menu français,
   panneau d'ouverture, Ouvrir récent, réglages, À propos, raccourcis, aide HTML, instantané.
3. **Coloration** : le surligneur applique les couleurs des lexers au stockage, ligne par ligne, en portant
   l'état (commentaire ou chaîne ouverte) d'une ligne à la suivante ; incrémental à chaque édition.
4. **Livraison** : `Scripts/bundle.sh` (version, bundle, signature), icône par script, aide en français,
   README avec les mesures (taille, démarrage).

## Phases

1. Squelette qui édite du texte brut, documents et onglets, gouttière, barre d'état, docs — **fait**.
2. Lexers et tests dorés par langage.
3. Surligneur dans l'app, mesure sur un fichier de 1 Mo.
4. Fichiers masqués, Ouvrir récent, encodages, langage (fait au squelette), vérification à la main des
   panneaux.
5. Guide d'aide complet, animations, finitions.
6. Bundle, instantanés de chaque fichier d'exemple, mesures, carte du projet.
