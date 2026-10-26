// Géométrie de la table, tirée de la maquette 1 « Fête foraine »
// (390 × 844 pt, iPhone 14/15). Toutes les cotes sont celles de la
// maquette ; elles sont ramenées à la zone sûre réelle de l'écran.
// Sans SwiftUI : CGPoint et CGSize viennent de Foundation sous Linux, de
// CoreGraphics sur Apple (où Foundation seul ne rend pas visible leur
// conformité à Equatable).

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Place d'un joueur autour de la table, vue depuis le joueur (toujours en bas).
public enum Place: String, CaseIterable, Sendable {
    case bas, gauche, haut, droite

    /// Le jeu tourne dans le sens des aiguilles d'une montre à l'écran :
    /// bas → gauche → haut → droite (comme les flèches de la maquette).
    public static func de(_ joueur: Int, moi: Int, nombreJoueurs n: Int) -> Place {
        let rel = ((joueur - moi) % n + n) % n
        if rel == 0 { return .bas }
        switch n {
        case 2: return .haut
        case 3: return rel == 1 ? .gauche : .droite
        default: return [.bas, .gauche, .haut, .droite][rel]
        }
    }
}

/// Position d'une carte : centre, taille, rotation (degrés).
public struct Pose: Equatable, Sendable {
    public var centre: CGPoint
    public var taille: CGSize
    public var rotation: Double

    public init(centre: CGPoint, taille: CGSize, rotation: Double = 0) {
        self.centre = centre
        self.taille = taille
        self.rotation = rotation
    }
}

public struct Disposition: Sendable {
    /// Taille de la zone sûre (sans barre d'état ni barre d'accueil).
    public let taille: CGSize
    public let moi: Int
    public let nombreJoueurs: Int

    /// Maquette : 390 × 844, zone sûre de y = 47 à y = 810.
    static let largeurMaquette: CGFloat = 390
    static let hautMaquette: CGFloat = 47
    static let hauteurMaquette: CGFloat = 763

    public init(taille: CGSize, moi: Int, nombreJoueurs: Int) {
        self.taille = taille
        self.moi = moi
        self.nombreJoueurs = nombreJoueurs
    }

    /// Échelle des objets : la plus petite des deux, pour que rien ne déborde
    /// sur un écran plus court (iPhone SE) ou plus étroit.
    public var echelle: CGFloat {
        min(taille.width / Self.largeurMaquette, taille.height / Self.hauteurMaquette)
    }

    /// Point de la maquette (coordonnées de l'écran 390 × 844) ramené à l'écran.
    public func m(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * taille.width / Self.largeurMaquette,
                y: (y - Self.hautMaquette) * taille.height / Self.hauteurMaquette)
    }

    public func t(_ l: CGFloat, _ h: CGFloat) -> CGSize { CGSize(width: l * echelle, height: h * echelle) }

    // MARK: - Repères fixes (maquette)

    public var pioche: CGPoint { m(139, 362) }
    public var defausse: CGPoint { m(251, 362) }
    /// Centre des flèches tournantes (repère du joueur actif).
    public var centreTable: CGPoint { m(195, 368) }
    public var rayonFleches: CGFloat { 120 * echelle }
    public var carteTable: CGSize { t(70, 100) }
    /// Carte piochée par moi, grande, entre « Remplacer » et « Défausser ».
    public var carteTenue: Pose { Pose(centre: m(195, 595), taille: t(94, 134)) }
    public var boutonCochon: CGPoint { m(326, 744) }
    /// Bandeau « À toi ! » (de x = 108 à 370, 46 pt de haut).
    public var banniere: CGPoint { m(239, 79) }
    public var boutonMenu: CGPoint { m(37, 77) }
    /// Légende de la carte piochée (« Tu as pioché un Roi ♠ : 0 point ! »).
    public var legende: CGPoint { m(195, 507) }
    public var boutonRemplacer: CGPoint { m(75, 598) }
    public var boutonDefausser: CGPoint { m(315, 598) }
    public var tailleBoutonAction: CGSize { t(122, 64) }
    public var diametreCochon: CGFloat { 100 * echelle }
    public var carteMain: CGSize { t(56, 82) }
    public var carteMini: CGSize { t(36, 52) }

    /// Centre du petit tas d'un adversaire.
    public func siege(_ place: Place) -> CGPoint {
        switch place {
        case .bas: return m(135.5, 731)
        case .haut: return m(195, 138)
        case .gauche: return m(45, 280)
        case .droite: return m(345, 280)
        }
    }

    /// Centre de l'étiquette « nombre de cartes + nom ».
    public func etiquette(_ place: Place) -> CGPoint {
        switch place {
        case .bas: return m(57, 815)
        case .haut: return m(195, 187)
        case .gauche: return m(46, 333)
        case .droite: return m(344, 333)
        }
    }

    /// Centre d'un élément de `taille` voulu en `centre`, ramené dans l'écran
    /// (à `marge` des bords) quand il déborderait. Les étiquettes « ORDI 1 »
    /// et « ORDI 3 » sont posées près des bords et grandissent avec le texte :
    /// elles glissent vers l'intérieur au lieu d'être coupées. Plus large que
    /// l'écran : centré.
    public func centreDansEcran(_ centre: CGPoint, taille t: CGSize, marge: CGFloat = 6) -> CGPoint {
        func borne(_ v: CGFloat, _ demi: CGFloat, _ total: CGFloat) -> CGFloat {
            let bas = marge + demi, haut = total - marge - demi
            return bas > haut ? total / 2 : min(max(v, bas), haut)
        }
        return CGPoint(x: borne(centre.x, t.width / 2, taille.width),
                       y: borne(centre.y, t.height / 2, taille.height))
    }

    // MARK: - « +1 » de pénalité

    /// Cadre du texte « +1 » (Lilita One 30 pt, ombre comprise).
    public var taillePlusUn: CGSize { t(44, 40) }

    /// Centre du « +1 » d'un joueur pénalisé, au repos (début de l'envol).
    /// Pour moi : à droite de l'étiquette « Toi », sous ma main, jamais
    /// posé sur mes cartes (l'étiquette fait au plus ~90 pt de large avec
    /// la pastille). Pour un ordi : en haut à droite de son étiquette.
    public func plusUn(_ place: Place) -> CGPoint {
        let e = etiquette(place)
        switch place {
        case .bas: return CGPoint(x: e.x + 76 * echelle, y: e.y)
        default: return CGPoint(x: e.x + 34 * echelle, y: e.y - 26 * echelle)
        }
    }

    /// Envol du « +1 » pendant qu'il s'efface : vers la droite pour moi
    /// (au-dessus, il traverserait ma main), vers le haut pour un ordi.
    public func envolPlusUn(_ place: Place) -> CGSize {
        place == .bas ? t(36, 0) : t(0, -36)
    }

    // MARK: - Pose d'une carte

    public func place(_ joueur: Int) -> Place { Place.de(joueur, moi: moi, nombreJoueurs: nombreJoueurs) }

    /// Pose d'une carte selon son lieu. `tailleMain` = nombre de cartes de
    /// la main concernée (l'éventail se resserre ou s'élargit).
    public func pose(_ lieu: Lieu, tailleMain: Int = 4, jeton: JetonID = 0) -> Pose {
        switch lieu {
        case .pioche(let p):
            // Paquet en relief : les cartes de dessous débordent en bas à droite.
            let d = CGFloat(min(p, 2)) * 2.5 * echelle
            return Pose(centre: CGPoint(x: pioche.x + d * 0.7, y: pioche.y + d), taille: carteTable)
        case .defausse(let p, let rang):
            // Dessus légèrement penché, dessous plus en vrac (stable par carte).
            let base = Double((rang * 37 + jeton * 11) % 19) - 9
            let rot = p == 0 ? 6 + base * 0.3 : -14 + base * 0.6
            let dx = p == 0 ? 0 : -4 * echelle
            return Pose(centre: CGPoint(x: defausse.x + dx, y: defausse.y + (p == 0 ? 0 : 2 * echelle)),
                        taille: carteTable, rotation: rot)
        case .tenue(let j):
            if j == moi { return carteTenue }
            // Carte tenue par un ordinateur : entre son siège et le centre.
            let s = siege(place(j))
            let c = centreTable
            return Pose(centre: CGPoint(x: s.x + (c.x - s.x) * 0.42, y: s.y + (c.y - s.y) * 0.42),
                        taille: t(50, 72))
        case .main(let j, let emp):
            return place(j) == .bas ? poseMaMain(emp, tailleMain) : poseAdverse(place(j), emp, tailleMain)
        }
    }

    /// Éventail du joueur : cartes de 56 × 82, pas de 61, rotation de 4° par
    /// carte, creux de 5 pt (maquette). L'éventail se resserre au-delà de
    /// 4 cartes pour ne jamais passer sous le bouton COCHON!.
    func poseMaMain(_ i: Int, _ n: Int) -> Pose {
        let n = max(n, 1)
        // Centres de x = 44 à x = 227 dans la maquette (4 cartes au pas de 61).
        let etendue: CGFloat = 183
        let pas = n > 1 ? min(61, etendue / CGFloat(n - 1)) : 0
        let milieu = CGFloat(n - 1) / 2
        let rel = CGFloat(i) - milieu
        let x = 135.5 + rel * pas
        let y = 731 + abs(rel) * 5 * (pas / 61)
        return Pose(centre: m(x, y), taille: carteMain, rotation: Double(rel) * 4 * Double(pas / 61))
    }

    /// Petit tas d'un adversaire : cartes de 36 × 52 qui se chevauchent.
    func poseAdverse(_ place: Place, _ i: Int, _ n: Int) -> Pose {
        let n = max(n, 1)
        let pas: CGFloat = n > 4 ? max(6, 40 / CGFloat(n - 1)) : 13
        let rel = CGFloat(i) - CGFloat(n - 1) / 2
        let s = siege(place)
        let centre = CGPoint(x: s.x + rel * pas * echelle, y: s.y)
        let rot: Double
        switch place {
        case .gauche: rot = Double(rel) * 5
        case .droite: rot = -Double(rel) * 5
        default: rot = 0
        }
        return Pose(centre: centre, taille: carteMini, rotation: rot)
    }
}
