# Règles appliquées par le moteur

Source qui fait foi : « RÈGLES MICHAEL » (`~/.hermes/projets/app-cochon.md`).
Quand elles laissent un point ouvert, le moteur suit le prototype jouable
d'août (`blufli-preview`), et c'est écrit ici. Chaque règle a ses tests
(`Paquets/CochonMoteur/Tests`).

## Règles

1. 52 cartes françaises, 4 cartes cachées par joueur, 2 à 4 joueurs. La
   première carte du talon est retournée sur la défausse.
2. Au début, chacun regarde 2 de ses cartes, une par une. En ligne, tout le
   monde regarde en même temps ; le jeu démarre quand le dernier a fini.
3. But : le plus petit total. As = 1, 2 à 10 = leur valeur, Valet et
   Dame = 10, Rois noirs (♣ ♠) = 0, Rois rouges (♥ ♦) = 30.
4. Tour : piocher dans la pioche ou prendre la défausse, puis
   - remplacer une de ses cartes (l'ancienne part, face visible, à la défausse) ;
   - ou, seulement si la carte vient de la pioche, la défausser.
   Une carte prise à la défausse doit remplacer une carte.
5. Pouvoirs, seulement pour un Valet ou une Dame **défaussé tout droit
   depuis la pioche** :
   - Valet : échanger à l'aveugle une de ses cartes avec une carte d'un
     adversaire (personne ne découvre de face) ;
   - Dame : regarder une de ses cartes.
6. Réflexe : après son coup, si l'une de ses cartes a le même rang que le
   dessus de la défausse, on peut l'écarter (la main raccourcit). Erreur :
   une carte de pénalité.
7. COCHON! : annoncé à la fin de son tour ; chacun des autres joue encore
   une fois (dernière orbite), puis tout est révélé et on compte.

## Points tranchés (à valider par Michael)

| Point | Choix du moteur | Origine |
|---|---|---|
| Qui peut tenter un réflexe ? | Le joueur dont c'est le tour, une fois, juste après son coup. | Prototype d'août |
| Réflexe raté | La carte montrée reprend sa place et devient connue de tous ; une carte de pénalité, face cachée, s'ajoute à la main (personne ne la connaît, lui non plus). Pioche vide : pas de pénalité. | Prototype (pénalité) ; « connue de tous » : il faut la montrer pour vérifier |
| Pouvoir obligatoire ? | Oui, une fois la carte défaussée (le prototype n'offre pas de « passer »). Sans cible possible (mains vides), il est perdu. | Prototype |
| Pioche épuisée | La manche s'arrête à la fin du tour où la pioche est vide, comme une fin normale. | Prototype |
| L'annonceur | Il ne rejoue pas pendant la dernière orbite. | Prototype |
| Égalité | Tous les joueurs à égalité au plus petit total gagnent. | — |
| Minuteur (15/30/60 s) | Réglage porté par la config ; c'est l'arbitre (app ou serveur) qui joue un coup par défaut à l'expiration, pas le moteur. | — |
