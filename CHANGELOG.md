# Changelog

## 0.9.0 — en cours (2026-10-23)

Première version de SimpleText, native (Swift, AppKit, TextKit 2), sans aucune dépendance.

- Documents AppKit : onglets, Ouvrir récent, Dupliquer, Renommer, Déplacer, versions, restauration au lancement.
- Tout fichier texte s'ouvre, quelle que soit son extension ; les binaires sont refusés. Encodage et fins de ligne détectés et conservés, indentation lue dans le fichier.
- Panneau d'ouverture avec case « Afficher les fichiers masqués ».
- Éditeur de code : numéros de ligne, ligne courante, indentation automatique, lignes dupliquées, supprimées ou déplacées, commentaires en une touche, recherche et remplacement, aller à la ligne.
- Palette sombre de la famille Simple ; barre d'état ; À propos, réglages, raccourcis (⌘/), aide (⌘?).
- `--snapshot` pour vérifier sans écran.
