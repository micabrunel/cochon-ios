// Vitesse de jeu et « Réduire les animations ». Toutes les durées de la
// table passent par ici : un seul endroit à régler, et des tests qui
// vérifient les cadences annoncées (distribution ~4 cartes/s, etc.).

import CochonMoteur

public enum Vitesse: String, CaseIterable, Codable, Sendable {
    case tranquille
    case normale
    case rapide

    /// Multiplie toutes les durées.
    public var facteur: Double {
        switch self {
        case .tranquille: return 1.4
        case .normale: return 1.0
        case .rapide: return 0.65
        }
    }

    public var nom: String {
        switch self {
        case .tranquille: return "Tranquille"
        case .normale: return "Normale"
        case .rapide: return "Rapide"
        }
    }
}

/// Comment l'écran doit animer une étape. L'app traduit chaque style en
/// courbe SwiftUI (voir DESIGN.md, « Mouvement »).
public enum StyleAnimation: String, Equatable, Sendable {
    /// Carte qui vole d'une place à l'autre (ressort, sans rebond).
    case vol
    /// Retournement 3D.
    case retournement
    /// Petit soulèvement, ou retour à plat.
    case soulevement
    /// Deux cartes qui se croisent (Valet) : accélère puis freine.
    case croisement
    /// Distribution : vol court et vif.
    case distribution
    /// Rien ne bouge : changement immédiat.
    case immediat
}

public struct Rythme: Equatable, Sendable {
    public var vitesse: Vitesse
    /// Réglage système « Réduire les animations » : pas de vol ni de
    /// retournement 3D (fondu court), rien qui tourne en continu. Les pauses
    /// restent, pour que le tour des ordinateurs reste lisible.
    public var reduire: Bool

    public init(vitesse: Vitesse = .normale, reduire: Bool = false) {
        self.vitesse = vitesse
        self.reduire = reduire
    }

    /// Durée d'une étape, en secondes, vitesse appliquée.
    public func duree(_ base: Double) -> Double { base * vitesse.facteur }

    /// Distribution : une carte toutes les 0,25 s à vitesse normale (4/s, comme UNO).
    public var intervalleDistribution: Double { duree(0.25) }

    /// Pause de « réflexion » d'un ordinateur avant un coup qui se voit
    /// (piocher, poser, pouvoir, réflexe, COCHON!). Les coups de service
    /// (passer le réflexe, finir le tour) s'enchaînent sans attendre.
    public func pauseAvant(_ coup: Coup) -> Double {
        switch coup {
        case .passerReflexe, .terminerTour: return 0
        case .regarder: return duree(0.15)
        case .piocher: return duree(0.55)
        case .remplacer, .defausserPiochee: return duree(0.6)
        case .echangerValet, .regarderDame: return duree(0.5)
        case .reflexe: return duree(0.35)
        case .annoncerCochon: return duree(0.4)
        }
    }

    /// Style effectivement joué, une fois « Réduire les animations » appliqué.
    public func style(_ s: StyleAnimation) -> StyleAnimation {
        reduire ? .immediat : s
    }

    /// Durée de l'animation elle-même (la courbe), pour l'app.
    public func dureeAnimation(_ s: StyleAnimation) -> Double {
        switch style(s) {
        case .vol: return duree(0.42)
        case .retournement: return duree(0.36)
        case .soulevement: return duree(0.18)
        case .croisement: return duree(0.6)
        case .distribution: return duree(0.3)
        // Réduire les animations : un fondu court remplace le mouvement.
        case .immediat: return reduire ? 0.2 : 0
        }
    }
}
