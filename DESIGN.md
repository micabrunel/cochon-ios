# DESIGN.md — COCHON! (iPhone)

Source de vérité visuelle de l'app. Référence : **maquette 1 « Fête
foraine »**, choisie par Michael le 26/10/2026
(`/srv/hermes/work/assets/cochon/maquettes/maquette-1.png`, source HTML
`maquettes/src/html/maquette-1.html`). Toutes les valeurs ci-dessous sont
relevées dans ce HTML ; aucune n'est un choix par défaut. Ce qui manque se
demande à Michael, on ne l'invente pas.

Code : `Cochon/Design/Theme.swift` (couleurs, polices, courbes, relief),
`Cochon/Design/CarteVue.swift` (cartes), `Cochon/Design/Mascotte.swift`,
`Cochon/Design/Fond.swift`. Géométrie de la table :
`Paquets/CochonMoteur/Sources/CochonTable/Disposition.swift`.

## Parti pris

Une fête foraine vue de dessus, comme une table d'UNO : rayons, bonbons en
relief, une mascotte cochon qui annonce les temps forts. L'énergie est sur
les bords et dans les boutons ; **le centre de la table reste calme** (jaune
clair, rayons effacés) pour que pioche, défausse et carte tenue se lisent
d'un coup d'œil pendant une longue partie.

Vigilance (recommandation de Lisa) : ne pas saturer de rose.
- Le rose ne vit qu'aux bords du fond, sur les dos de cartes et les
  compteurs. Les surfaces de lecture (cartes, étiquettes, panneaux) sont
  blanches.
- Les rayons sont masqués au centre (dégradé radial) et **ne tournent pas
  pendant la partie** ; ils tournent lentement à l'accueil seulement.
- Le turquoise (« à toi ») et le jaune (flèches, menu) équilibrent le rose.

## Couleurs (jetons `Palette`)

| Jeton | Hex | Usage |
|---|---|---|
| `fondCentre` | `#FFF7A8` | centre du dégradé (0 %) |
| `fondJaune` | `#FFD23F` | 16 % |
| `fondOrange` | `#FF9A1F` | 38 % |
| `fondRose` | `#FF3D6E` | 72 % |
| `fondBord` | `#D4126A` | bords (100 %) |
| `rose` | `#FF3D7F` | dos de carte, compteur des ordis |
| `roseRayonClair` / `roseRayonFonce` | `#FF5C96` / `#FF2F73` | rayons du dos de carte |
| `roseOmbre` | `#B3003F` | ombre du groin |
| `framboise` | `#C4135A` | pastilles « Pioche », légendes, narines |
| `framboiseTexte` | `#B3104F` | texte et socle des étiquettes |
| `framboiseSocle` | `#7A0A2C` | socle des pastilles, ombre des titres |
| `prune` | `#5A0D2E` | texte courant sur fond clair |
| `jaune` / `jauneOmbre` / `jauneSocle` | `#FFE14D` / `#F0A400` / `#8E0E44` | bouton menu, groin |
| `jauneIcone` | `#A3124E` | icône du menu |
| `fleche` | `#FFF36B` | flèches tournantes, contour de ma main, indice de pioche |
| `turquoise` / `turquoiseOmbre` / `turquoiseSocle` | `#1FC7B6` / `#0F9C8E` / `#0A6E64` | bandeau « À toi ! », pastille de tour |
| `vert` / `vertOmbre` / `vertSocle` | `#2FD06A` / `#19A14B` / `#0F6E31` | « Remplacer », « Jouer » |
| `bleu` / `bleuOmbre` / `bleuSocle` | `#2E8BFF` / `#1663D0` / `#0C3F8F` | « Défausser », « Fin du tour » |
| `cochonClair` / `cochonRouge` / `cochonOmbre` | `#FF7AA6` / `#E8174F` / `#A80F3D` | bouton COCHON! |
| `carteRouge` | `#E8173F` | ♥ ♦ |
| `encre` | `#1D1A3A` | ♣ ♠, badge « vue » |
| `carteFondBas` | `#FFF4F7` | bas du dégradé des faces, fonds de panneaux |
| `ombreCarte` | rgb(120, 0, 50) | ombres des cartes et du bouton COCHON! |

Le bandeau passe en framboise quand c'est un ordi qui joue (même relief).

## Typographie

| Rôle | Police | Graisse | Exemples |
|---|---|---|---|
| Titres, boutons, valeurs des cartes, COCHON! | **Lilita One** (`LilitaOne`) | 400 | « À toi ! » 21 pt, boutons 18 pt, COCHON! 22 pt |
| Légendes, consignes | **Baloo 2** (`Baloo2-Bold`) | 700 | légende de la carte piochée 14 pt, « Tour 6 » 13 pt |
| Étiquettes, badges | **Baloo 2** (`Baloo2-ExtraBold`) | 800 | « ORDI 2 » 13 pt, « vue » 12 pt |

- Fichiers dans `Cochon/Polices` (licence OFL jointe), déclarés dans
  `UIAppFonts`. Baloo 2 est livrée en deux instances fixes (700, 800)
  tirées de la police variable.
- Textes suivent Dynamic Type (`relativeTo:`) ; les valeurs imprimées sur
  les cartes sont à taille fixe (proportionnelles à la carte).
- Tutoiement, phrases courtes, casse de phrase. Seuls « COCHON! » et les
  noms « ORDI 1/2/3 » sont en capitales (maquette).

## Rayons et relief

- Rayons : boutons d'action 20 pt, menu 14 pt, bandeau 16 pt, étiquettes et
  pastilles en capsule, panneaux 22-28 pt. Cartes : 13 % de la largeur
  (6 pt en 36, 9 pt en 56/70, 12 pt en 94).
- **Relief « bonbon »** (`BoutonBonbon`) : face pleine, bande sombre de
  6 pt en bas (`…Ombre`), reflet blanc 45 % sur le haut, socle plein décalé
  de 5 pt (`…Socle`), ombre douce de la couleur du socle à 35 %. Enfoncé :
  le bouton descend de 60 % de la profondeur et passe à `scale(0.97)`.
- Étiquettes et pastilles : socle plein décalé de 3 pt, sans flou.
- Cartes : ombre pleine `0 3 0` à 35 % + ombre douce `0 4 8` à 30 %
  (`ombreCarte`). Carte soulevée : + ombre douce 12 pt.

## Cartes

- **Dos** : fond rose, 24 rayons alternés `#FF5C96` / `#FF2F73`, bord blanc
  (5,4 % de la largeur), **groin** jaune `#FFE14D` au centre (62 % de la
  largeur, rapport 1,3, penché de -12°, bord blanc, ombre `#B3003F`), deux
  narines `#C4135A`.
- **Face** : dégradé blanc → `#FFF4F7`, bord blanc ; index (rang + couleur)
  en haut à gauche et en bas à droite (retourné), grand rang au centre.
  Rangs : A, 2…10, V, D, R.
- Tailles (maquette 390 pt) : ma main 56 × 82, ordis 36 × 52, tas 70 × 100,
  carte piochée 94 × 134.
- Ma main porte un contour jaune `fleche` de 3 pt ; il s'allume (halo) quand
  il faut toucher une de mes cartes. Une carte déjà regardée porte le badge
  « vue » (œil + « vue », `encre` / `fleche`) : aide-mémoire sans montrer la
  face.

## Mascotte

Cochon rose de face (SVG 100 × 100 de la maquette redessiné dans
`Mascotte.swift`) : oreilles pointues `#FF8FB4`, tête `#FFB3CB`, trait
`#C94477`, joues, groin, sourire. Elle apparaît : à cheval sur le bandeau
(64 pt, -10°), sur le panneau de départ, dans l'annonce COCHON!, sur les
résultats et en grand à l'accueil. Jamais en décor répété.

## Table (maquette 390 × 844, zone sûre y = 47 → 810)

```
 [≡]  [🐷 À toi !            Tour 6 ]        menu 37,77 · bandeau 108→370
              ▢▢▢   (ORDI 2)                 haut : tas 195,138 · étiquette 195,187
 ▢▢▢▢          ↻                ▢▢▢▢         gauche 45,280 / droite 345,280
(ORDI 1)   [Pioche] [Défausse] (ORDI 3)      étiquettes 46,333 / 344,333
               ↺                             tas 139,362 et 251,362 · flèches r = 96
   ( Tu as pioché un Roi ♠ : 0 point ! )     légende 195,507
 [↓ Remplacer]   [ R♠ ]   [↑ Défausser]      boutons 75,598 / 315,598 · carte 195,595
 ▢ ▢ ▢ ▢   (main en éventail)    (COCHON!)   main centrée 135,5 · bouton 326,744 Ø100
 (● Toi 4)                                   étiquette 57,815
```

- Joueur toujours en bas. 2 joueurs : l'ordi en haut ; 3 : gauche et
  droite ; 4 : gauche, haut, droite. Le jeu tourne dans le sens des
  aiguilles d'une montre à l'écran (bas → gauche → haut → droite), comme les
  flèches.
- Éventail : pas de 61 pt, 4° de rotation par carte, creux de 5 pt aux
  bouts. Au-delà de 4 cartes (pénalités) il se resserre et ne passe jamais
  sous le bouton COCHON! (test).
- Petits écrans : la géométrie est ramenée à la zone sûre ; les tailles
  suivent la plus petite échelle (test « tout tient sur un iPhone SE »).

## Mouvement (référence : UNO)

Principe : chaque mouvement explique ce qui change (une carte qui part, qui
arrive, qui se retourne). Pas d'entrée décorative par section. Les
animations répondent au jeu ; seules deux boucles tournent en continu
pendant la partie : les flèches du centre et la pastille du joueur actif.

| Moment | Ce qu'on voit | Courbe | Durée (vitesse normale) |
|---|---|---|---|
| Distribution | les cartes volent une par une depuis la pioche, à tour de rôle, puis la 1re carte se pose sur la défausse | ressort, rebond 0,18 | 1 carte / 0,25 s (4/s), vol 0,3 s |
| Carte touchée | elle se soulève (+16 pt, ×1,12, à plat) puis vole à sa place | sortie `(0.23, 1, 0.32, 1)` puis ressort sans rebond | 0,18 s + 0,42 s |
| Pioche | la carte vole vers moi en grandissant, puis **retournement 3D** (axe vertical, perspective) | ressort, puis `(0.77, 0, 0.175, 1)` | 0,42 s + 0,36 s |
| Joueur actif | **flèches courbes** qui tournent dans le sens du jeu (8 s le tour), halo blanc qui glisse sous l'étiquette du joueur, **pastille turquoise** qui palpite, bandeau qui rebondit sur « À toi ! » | linéaire / ressort | continu ; glissement 0,5 s |
| Tu peux piocher | triangle jaune qui **rebondit** au-dessus de la pioche | ressort, rebond 0,55 | 0,8 s le cycle |
| Valet | les deux cartes se soulèvent ensemble puis **se croisent** | `(0.77, 0, 0.175, 1)` | 0,25 s + 0,6 s |
| Dame (moi) | ma carte se soulève, se retourne, reste lisible, se recache | sortie + retournement | 1,6 s visible |
| Dame / regard (ordi) | sa carte se soulève et **s'incline vers lui** (52° sur l'axe horizontal), face cachée pour moi | sortie | 0,9 s |
| Réflexe réussi | la carte se retourne puis file à la défausse, bulle « Réflexe ! » | retournement + vol | 0,45 s + 0,9 s |
| Réflexe raté | la carte se montre à tous, se recache, une carte de pénalité vole de la pioche, **« +1 » flottant** près de l'étiquette | retournement + vol | 1 s + 0,9 s |
| COCHON! | voile framboise, mascotte et titre qui surgissent | ressort, rebond 0,35 | 1,8 s |
| Fin de manche | les mains se retournent joueur par joueur, puis le classement | retournement | 0,45 s par joueur |
| Bouton | enfoncement sur le socle, `scale(0.97)` | sortie | 0,14 s |
| Bouton COCHON! qui s'allume | un frétillement (-6°, +6°, -3°, 0) | cubique | 0,42 s |

- **Tour des ordis rythmé** : pause de « réflexion » avant chaque coup qui
  se voit (piocher 0,55 s, poser 0,6 s, pouvoir 0,5 s, réflexe 0,35 s),
  aucune avant les coups de service (passer le réflexe, finir le tour).
- **Vitesse** (Paramètres) : Tranquille ×1,4, Normale ×1, Rapide ×0,65 sur
  toutes les durées.
- **Réduire les animations** (réglage iOS) : aucune carte ne vole ni ne se
  soulève (changement de place immédiat), les retournements deviennent des
  fondus de 0,2 s, flèches, rayons, pastille et indice ne bougent plus. Les
  **pauses restent** : le tour des ordis reste lisible.
- Toutes les durées sont dans `CochonTable/Rythme.swift` et
  `Choregraphie.swift`, testées sous Linux.

## Haptique

| Moment | Retour |
|---|---|
| Je soulève / regarde une carte, c'est mon tour | sélection |
| Je pioche, je défausse, 1re carte de la défausse | impact léger |
| Je remplace, échange de Valet | impact moyen |
| COCHON! | impact fort |
| Mon réflexe réussi | succès |
| Mon réflexe raté | erreur, puis avertissement à la pénalité |
| Fin de manche | succès |

## Accessibilité

- VoiceOver : chaque carte est un élément (« Ta carte 2 : déjà vue »,
  « Défausse : 7 de cœur, 7 points ») ; une seule carte par tas est lue ;
  les annonces (« Réflexe ! », « COCHON! ») sont aussi annoncées à la voix.
- Zones de toucher élargies de 6 pt autour des cartes.
- Contraste : textes blancs sur framboise, turquoise ou bleu en Lilita One
  épaisse ; textes sur fond clair en `framboiseTexte` ou `prune`.

## À ne pas faire

- Pas de rose plein écran ni de rayons qui tournent pendant la partie.
- Pas de nouvelle couleur, police, ombre ou rayon hors de ce fichier.
- Pas d'écran simulé : ce qui n'est pas branché s'affiche « bientôt ».
- Pas d'animation sur un geste répété très souvent qui ralentirait le jeu :
  les vols restent sous 0,45 s.
