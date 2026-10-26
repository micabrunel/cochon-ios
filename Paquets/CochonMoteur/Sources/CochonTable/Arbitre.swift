// L'arbitre d'une partie contre l'ordinateur, sur le téléphone, sans
// horloge ni interface : il garde l'état complet, ne montre que la vue du
// joueur humain et fait jouer les ordinateurs depuis leur seule vue.
// L'écran (TableModele) l'appelle et anime les événements rendus.
// En ligne, ce rôle passera au serveur : l'écran ne lira toujours que la vue.

import CochonIA
import CochonMoteur

public struct Arbitre: Sendable {
    /// Siège du joueur humain.
    public let moi: Int
    public private(set) var etat: EtatPartie
    private let ordinateurs: [Ordinateur]

    public init(config: ConfigPartie, niveau: NiveauIA, graine: UInt64, moi: Int = 0) throws {
        self.moi = moi
        etat = try Moteur.nouvellePartie(config: config, graine: graine)
        ordinateurs = (0..<config.nombreJoueurs).map { Ordinateur(niveau: niveau, graine: graine &+ UInt64($0)) }
    }

    public var vue: VueJoueur { etat.vue(pour: moi) }

    /// Joue un coup du joueur humain. L'état ne bouge pas si le moteur le refuse.
    public mutating func jouer(_ coup: Coup) throws -> [Evenement] {
        let r = try Moteur.appliquer(Action(joueur: moi, coup: coup), a: etat)
        etat = r.etat
        return r.evenements
    }

    /// Prochain coup d'un ordinateur, s'il y en a un à jouer (sans l'appliquer).
    public func prochainCoupOrdinateur() -> Action? {
        for j in 0..<etat.nombreJoueurs where j != moi {
            if let coup = ordinateurs[j].choisir(etat.vue(pour: j)) { return Action(joueur: j, coup: coup) }
        }
        return nil
    }

    /// Joue ce coup d'ordinateur. Un coup refusé (ne devrait pas arriver :
    /// l'ordinateur choisit parmi les coups possibles) laisse l'état intact.
    public mutating func jouerOrdinateur(_ action: Action) throws -> [Evenement] {
        precondition(action.joueur != moi, "coup humain joué comme un coup d'ordinateur")
        let r = try Moteur.appliquer(action, a: etat)
        etat = r.etat
        return r.evenements
    }
}
