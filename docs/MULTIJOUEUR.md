# Multijoueur en ligne — option recommandée

Note de cadrage (26/10/2026), rien n'est implémenté. Michael veut le jeu en
ligne très vite après la version contre l'ordinateur.

## Le point qui décide : les cartes cachées

À COCHON!, presque toute l'information est secrète (cartes face cachée,
pioche, carte tirée, carte regardée avec la Dame). Il faut donc **un
arbitre qui détient l'état complet et n'envoie à chaque joueur que sa
vue**. Sinon, un téléphone modifié lit les cartes des autres.

## Les options

| | Game Center seul (GameKit) | Serveur maison sur le cluster |
|---|---|---|
| Coût | Gratuit | Gratuit (cluster de Michael) |
| Tour par tour (`GKTurnBasedMatch`) | Les données de partie sont **partagées avec tous les joueurs** : impossible de cacher les cartes. Notifications lentes (secondes), mauvais pour le réflexe. | — |
| Temps réel (`GKMatch`) | Pair à pair : un téléphone « hôte » détient l'état. Il peut tricher, et si l'hôte quitte, la partie meurt. | — |
| Arbitre fiable | Non | **Oui** : le serveur rejoue chaque coup avec le même `CochonMoteur` (déjà testé sous Linux en CI) |
| Reconnexion | Fragile | Simple : le serveur renvoie la vue courante (journal de la partie) |
| Places vides | — | Remplies par `CochonIA` côté serveur |
| Exploitation | Rien à héberger | Un service de plus à faire tourner (Fabien) |

## Recommandation

**Serveur maison sur le cluster, avec Game Center pour l'identité et les
invitations.**

- **Serveur** : Swift sur Linux (Hummingbird 2, ou Vapor 4), conteneur sur
  le cluster, exposé par un tunnel Cloudflare comme les autres services. Il
  importe `CochonMoteur` tel quel : aucune règle n'est réécrite.
- **Connexion** : WebSocket. Le téléphone envoie `{partie, numeroCoup, coup}`
  (le JSON des coups est déjà figé par les tests) ; le serveur valide avec
  `Moteur.appliquer`, ajoute le coup au journal, puis envoie à chacun les
  événements publics et **sa** `VueJoueur`. Un coup en retard (numéro
  dépassé) est refusé.
- **Stockage** : le journal `(config, graine, actions)` de chaque partie
  (SQLite pour commencer) : reprise après coupure et relecture d'une partie.
- **Minuteur** : tenu par le serveur ; à l'expiration il joue le coup par
  défaut (piocher, défausser, passer, terminer).
- **Identité** : Game Center (`GKLocalPlayer`, gratuit, aucun compte à
  créer). Le serveur vérifie la signature d'identité Game Center
  (`fetchItems(forIdentityVerificationSignature:)`). Invitations : lien ou
  code de partie entre amis d'abord, recherche de joueurs ensuite.
- **Ce que le socle prévoit déjà** : actions `Codable`, état et vue
  sérialisables, rejeu déterministe, ouverture simultanée, `numeroCoup`,
  événements sans face privée, IA qui ne lit que la vue.

Limite à connaître : le jeu en ligne dépendra de la disponibilité du
cluster et de la connexion de la maison. Si cela devient gênant, le même
conteneur se déplace ailleurs sans changer l'application.
