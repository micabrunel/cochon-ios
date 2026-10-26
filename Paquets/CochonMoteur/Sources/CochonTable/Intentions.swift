// Gestes du joueur sur la table → coups du moteur. Aucune règle ici : un
// geste ne devient un coup que si ce coup figure dans `vue.coupsPossibles`.
// Deux gestes enchaînent deux coups pour épargner un tap inutile :
// « Fin du tour » (passer le réflexe puis terminer) et « COCHON! » (passer
// le réflexe puis annoncer).

import CochonMoteur

public enum Geste: Equatable, Sendable {
    case pioche
    case defausse
    case maCarte(Int)
    case carteAdverse(joueur: Int, emplacement: Int)
    case boutonRemplacer
    case boutonDefausser
    case finDuTour
    case cochon
}

public enum Reponse: Equatable, Sendable {
    /// Coups à jouer dans l'ordre ; l'écran s'arrête au premier refusé.
    case jouer([Coup])
    /// Valet : première carte choisie (la mienne), en attente de la carte adverse.
    case choisirValet(Int)
    /// « Remplacer » touché : l'écran attend la carte de la main.
    case attendreRemplacement
    case rien
}

/// Ce que la table propose au joueur, pour allumer ou éteindre les commandes.
public struct Commandes: Equatable, Sendable {
    /// Indice qui rebondit au-dessus de la pioche.
    public var piochePossible = false
    public var defaussePrenable = false
    /// « Remplacer » / « Défausser » autour de la carte piochée.
    public var remplacerVisible = false
    public var defausserVisible = false
    /// Cartes de ma main qu'on peut toucher maintenant.
    public var mainTouchable = false
    /// Cartes adverses touchables (Valet, ma carte déjà choisie).
    public var adversesTouchables = false
    public var finDuTourVisible = false
    public var cochonActif = false

    public init() {}
}

public enum Intentions {

    public static func reponse(_ geste: Geste, vue: VueJoueur, valetMien: Int? = nil) -> Reponse {
        let p = vue.coupsPossibles
        func si(_ coups: [Coup]) -> Reponse {
            guard let premier = coups.first, p.contains(premier) else { return .rien }
            return .jouer(coups)
        }
        switch geste {
        case .pioche:
            return si([.piocher(source: .pioche)])

        case .defausse:
            // Toucher la défausse en tenant une carte de la pioche = la défausser.
            if p.contains(.defausserPiochee) { return .jouer([.defausserPiochee]) }
            return si([.piocher(source: .defausse)])

        case .maCarte(let i):
            switch vue.phase {
            case .ouverture: return si([.regarder(emplacement: i)])
            case .cartePiochee: return si([.remplacer(emplacement: i)])
            case .pouvoirDame: return si([.regarderDame(emplacement: i)])
            case .reflexe: return si([.reflexe(emplacement: i)])
            case .pouvoirValet:
                guard vue.estMonTour, vue.maMain.indices.contains(i) else { return .rien }
                return .choisirValet(i)
            default: return .rien
            }

        case .carteAdverse(let adv, let sien):
            guard let mien = valetMien else { return .rien }
            return si([.echangerValet(monEmplacement: mien, adversaire: adv, sonEmplacement: sien)])

        case .boutonRemplacer:
            guard vue.estMonTour, case .cartePiochee = vue.phase else { return .rien }
            return .attendreRemplacement

        case .boutonDefausser:
            return si([.defausserPiochee])

        case .finDuTour:
            switch vue.phase {
            case .reflexe: return si([.passerReflexe, .terminerTour])
            case .finDeTour: return si([.terminerTour])
            default: return .rien
            }

        case .cochon:
            guard vue.cochonPar == nil else { return .rien }
            switch vue.phase {
            case .reflexe: return si([.passerReflexe, .annoncerCochon])
            case .finDeTour: return si([.annoncerCochon])
            default: return .rien
            }
        }
    }

    public static func commandes(_ vue: VueJoueur, valetMien: Int? = nil) -> Commandes {
        var c = Commandes()
        let p = vue.coupsPossibles
        c.piochePossible = p.contains(.piocher(source: .pioche))
        c.defaussePrenable = p.contains(.piocher(source: .defausse))
        if vue.estMonTour, case .cartePiochee = vue.phase {
            c.remplacerVisible = true
            c.defausserVisible = p.contains(.defausserPiochee)
        }
        c.mainTouchable = p.contains { coup in
            switch coup {
            case .regarder, .remplacer, .regarderDame, .reflexe: return true
            case .echangerValet: return valetMien == nil
            default: return false
            }
        }
        c.adversesTouchables = valetMien != nil && p.contains { if case .echangerValet = $0 { return true } else { return false } }
        c.finDuTourVisible = p.contains(.passerReflexe) || p.contains(.terminerTour)
        c.cochonActif = vue.cochonPar == nil && (p.contains(.passerReflexe) || p.contains(.annoncerCochon))
        return c
    }
}
