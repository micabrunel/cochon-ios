# COCHON! — iPhone

Jeu de cartes COCHON! en application iPhone native (SwiftUI, iOS 17+),
d'abord contre l'ordinateur, puis en ligne.

- `Paquets/CochonMoteur` : règles (`CochonMoteur`) et ordinateur (`CochonIA`), Swift pur, testés.
- `Cochon/` : l'application (écran minimal de vérification en attendant la maquette).
- `docs/ARCHITECTURE.md` : choix techniques. `docs/REGLES.md` : règles appliquées.
  `docs/MULTIJOUEUR.md` : option recommandée pour le jeu en ligne.

Tests du moteur : `cd Paquets/CochonMoteur && swift test` (Mac ou Linux, Swift 6.1).

Sur le Mac : `xcodegen generate && open Cochon.xcodeproj` (le projet Xcode
n'est pas versionné). Le travail se fait sur branche + PR, relue par Gilles.
