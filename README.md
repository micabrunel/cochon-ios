# COCHON! — iPhone

Jeu de cartes COCHON! en application iPhone native (SwiftUI, iOS 17+),
d'abord contre l'ordinateur, puis en ligne.

- `Paquets/CochonMoteur` : règles (`CochonMoteur`), ordinateur (`CochonIA`) et logique
  d'affichage de la table (`CochonTable`), Swift pur, testés.
- `Cochon/` : l'application (table « Fête foraine », accueil, paramètres, règles, résultats).
- `DESIGN.md` : couleurs, polices, relief, cartes, mascotte, mouvement (maquette 1).
- `docs/ARCHITECTURE.md` : choix techniques. `docs/REGLES.md` : règles appliquées.
  `docs/MULTIJOUEUR.md` : option recommandée pour le jeu en ligne.

Tests du moteur et de la table : `cd Paquets/CochonMoteur && swift test` (Mac ou Linux, Swift 6.1).

Sur le Mac : `xcodegen generate && open Cochon.xcodeproj` (le projet Xcode
n'est pas versionné). Le travail se fait sur branche + PR, relue par Gilles.
