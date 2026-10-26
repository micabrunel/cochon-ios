# Architecture — COCHON! iPhone

Décision de Michael (26/10/2026) : application iPhone native, feuille
blanche, d'abord contre l'ordinateur, multijoueur en ligne très vite
ensuite. Chef de projet : Ben. Les règles qui font foi sont dans
`docs/REGLES.md`.

## Choix techniques

| Sujet | Choix | Pourquoi |
|---|---|---|
| Interface | **SwiftUI** pour la table, les cartes, les menus et le HUD ; **SpriteKit** seulement en calque d'effets (`SpriteView` transparent) | Voir ci-dessous. |
| Version | **iOS 17+** | `@Observable`, `keyframeAnimator` / `phaseAnimator`, `sensoryFeedback`, `onChange` à deux valeurs. Plus de 90 % des iPhone actifs. |
| Projet Xcode | **XcodeGen** (`project.yml`), `.xcodeproj` non versionné | Comme `dermelia-scan-ios` : lisible, relisible, pas de conflit de projet. |
| Règles | Paquet Swift pur **`Paquets/CochonMoteur`** (Foundation seulement) | Testé sous Linux comme sur iPhone : le même code arbitrera les parties en ligne côté serveur. |
| Ordinateur | Cible **`CochonIA`** du même paquet | Ne reçoit que la vue de son siège : il ne peut pas tricher. |
| Identifiant | `com.micabrunel.cochon` | Proposé par la carte, en attente de la fiche App Store Connect. |

### SwiftUI + SpriteKit, et pas l'un des deux seul

- La table de COCHON! compte peu d'objets en mouvement (au plus 4 mains de
  4 à 6 cartes, la pioche, la défausse, une carte tenue). SwiftUI les anime
  sans peine à 120 Hz : cartes qui volent d'une place à l'autre
  (`matchedGeometryEffect`), retournement (`rotation3DEffect`), éventail,
  rebonds (`keyframeAnimator`). On garde ainsi la mise en page sur toutes
  les tailles d'iPhone, VoiceOver, Dynamic Type et des écrans testables.
- Les effets de la référence UNO (paillettes, rayons qui tournent,
  explosion du bouton COCHON!, confettis de fin) demandent des centaines de
  particules : c'est le travail de SpriteKit (`SKEmitterNode`, fichiers
  `.sks` réglables). Il tourne dans un calque transparent au-dessus de la
  table, sans toucher aux règles ni au jeu.
- Tout en SpriteKit obligerait à redessiner menus, textes et accessibilité
  à la main ; tout en SwiftUI rendrait les particules coûteuses.

## Le moteur de règles (`Paquets/CochonMoteur`)

```
Sources/CochonMoteur/
  Carte.swift      52 cartes, valeurs, codes d'échange (« 10C », « RP »), EnsembleCartes (52 bits)
  Aleatoire.swift  SplitMix64 + Fisher-Yates : même graine, même donne, partout
  Etat.swift       EtatPartie (valeur immuable hors du module), Phase, ConfigPartie
  Action.swift     Coup / Action (Codable), ErreurMoteur, Evenement (publics)
  Moteur.swift     nouvellePartie(config:graine:), appliquer(_:a:) → (état, événements), scores
  Vue.swift        VueJoueur : ce qu'un joueur a le droit de savoir, coupsPossibles
  Journal.swift    JournalPartie = (config, graine, actions) → rejouer()
Sources/CochonIA/
  Ordinateur.swift niveaux facile et malin, ne lisent que VueJoueur
```

Principes :

1. **État immuable, fonction pure.** `Moteur.appliquer(action, a: etat)` rend
   un nouvel état ou lève une `ErreurMoteur` ; l'état d'origine ne bouge
   jamais. Pas d'horloge, pas de hasard caché : seule la donne utilise la
   graine.
2. **Qui a vu quoi.** Les 52 cartes sont distinctes et leurs déplacements
   sont publics (chacun voit une carte changer de place). Il suffit donc de
   retenir, par joueur, les faces qu'il a vues (`connues`) pour savoir ce
   qu'il connaît, y compris après un échange de Valet.
3. **La vue est le seul canal vers un joueur.** `etat.vue(pour: j)` remplace
   par `nil` toute carte que `j` n'a jamais vue. L'écran, l'ordinateur et,
   en ligne, chaque téléphone ne reçoivent que cela. Un test vérifie que
   deux états qui ne diffèrent que par une carte jamais vue donnent la même
   vue.
4. **Événements publics.** `appliquer` rend aussi la liste de ce qui s'est
   passé (pour les animations et le journal) ; elle ne contient aucune
   face privée, on peut la diffuser telle quelle.
5. **Rejouable.** Une manche = `(config, graine, actions)`. Le format JSON
   des coups est figé par un test (contrat avec le futur serveur), l'état
   s'encode toujours pareil (pas de `Set` à l'ordre variable).
6. **`numeroCoup`** avance à chaque coup accepté : en ligne, un coup arrivé
   en retard (numéro dépassé) sera refusé.

## L'ordinateur (`CochonIA`)

- `Ordinateur(niveau:graine:).choisir(vue) -> Coup?` : un coup pris parmi
  `vue.coupsPossibles`, déterministe pour une graine donnée.
- Une carte inconnue est estimée à la moyenne des cartes **jamais vues**
  (la défausse et ce qu'il a regardé sont décomptés).
- **Facile** : oublie 35 % des cartes vues (toujours les mêmes, comme un
  joueur distrait), ne prend la défausse que pour un As ou un 2, joue un
  coup au hasard une fois sur sept environ, Valet au hasard.
- **Malin** : se souvient de tout, garde Valet et Dame quand ils rapportent
  plus qu'un remplacement, donne sa pire carte contre la meilleure carte
  connue d'en face, tente le réflexe seulement sur une carte connue,
  annonce COCHON! sur une petite main sûre ou en fin de pioche s'il mène.
- Mesure (test `testMalinBatFacile`, 300 manches en tête-à-tête) : malin
  gagne 275 manches, facile 19 ; moyenne 7,1 points contre 20,3.

## L'application

- `Cochon/PartieModele.swift` : l'arbitre local (état complet, ordinateurs,
  journal). En ligne, ce rôle passe au serveur ; l'écran ne lira toujours
  que la vue du joueur.
- `Cochon/TableMinimaleView.swift` : **écran de vérification** volontairement
  sobre (2 à 4 joueurs, niveau, mode « Test » qui laisse les cartes connues
  visibles). La vraie table attend la maquette choisie par Michael (carte
  de Lisa) ; aucune couleur ni police définitive n'est posée ici.
- Icône provisoire (groin rose) pour que TestFlight accepte l'envoi.

## Intégration continue

| Flux | Où | Quand | Rôle |
|---|---|---|---|
| `Moteur` | runners Linux du cluster (`self-hosted, linux, cluster`), image `swift:6.1` | chaque PR et `main` | **Obligatoire avant fusion** : tous les tests du moteur et de l'IA. |
| `Compiler` | Mac auto-hébergé (`self-hosted, macOS`) | chaque PR et `main` | Tests du moteur sur macOS + compilation de l'app pour iPhone, sans signature. |
| `TestFlight` | Mac auto-hébergé | à la demande | Archive signée par Apple (clé ASC) et envoi sur TestFlight. |

Les Mac hébergés par GitHub sont payants sur un dépôt privé (refusés pour
facturation sur `dermelia-scan-ios`) : on n'en utilise pas. Sans Mac en
ligne, `Compiler` reste en attente (jaune), il ne passe pas au rouge. Le Mac
de Michael s'installe en une ligne : `scripts/installer-runner-mac.sh`.

Lancer les tests en local (Mac, ou Linux avec Swift 6.1) :

```
cd Paquets/CochonMoteur && swift test
```
