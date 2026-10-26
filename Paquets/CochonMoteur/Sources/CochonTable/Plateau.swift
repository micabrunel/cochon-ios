// Les cartes physiques de la table, vues par l'écran du joueur.
//
// Chaque carte est un jeton à identité stable (0 à 51) : c'est ce qui permet
// à l'écran de la faire voler d'une place à l'autre au lieu de la faire
// disparaître ici et réapparaître là. Le plateau ne connaît aucune règle :
// il rejoue les déplacements que le moteur annonce dans ses événements
// (publics) et ne retient que les faces que le joueur a le droit de voir.

import CochonMoteur

public typealias JetonID = Int

/// Où se trouve une carte sur la table.
public enum Lieu: Hashable, Sendable {
    /// Dans la pioche ; `profondeur` 0 = dessus.
    case pioche(profondeur: Int)
    /// Dans la défausse ; `profondeur` 0 = dessus. `rang` = position depuis le fond (stable).
    case defausse(profondeur: Int, rang: Int)
    case main(joueur: Int, emplacement: Int)
    /// Tenue en l'air par ce joueur (carte piochée).
    case tenue(joueur: Int)
}

/// Un déplacement ou un changement d'aspect, appliqué d'un bloc par l'écran.
public enum Mouvement: Equatable, Sendable {
    /// Distribution : dessus de la pioche vers la main de ce joueur.
    case distribuer(joueur: Int)
    /// Dessus de la pioche retourné sur la défausse.
    case retournerSurDefausse(Carte)
    /// Prise dans la pioche ou la défausse ; `face` connue du joueur ou `nil`.
    case prendre(joueur: Int, source: Source, face: Carte?)
    /// La carte tenue (montrée ou non) : retournement.
    case montrerTenue(Bool)
    /// La carte tenue prend la place `emplacement` ; l'ancienne part, face visible, à la défausse.
    case remplacer(joueur: Int, emplacement: Int, ancienne: Carte)
    /// La carte tenue part à la défausse.
    case defausserTenue(Carte)
    /// Valet : deux cartes échangent leur place, faces cachées.
    case echanger(joueur: Int, emplacement: Int, adversaire: Int, sonEmplacement: Int)
    /// Réflexe réussi : la carte quitte la main pour la défausse (la main se resserre).
    case ecarter(joueur: Int, emplacement: Int, carte: Carte)
    /// Carte de pénalité : dessus de la pioche vers la fin de la main.
    case penalite(joueur: Int)
    case soulever(joueur: Int, emplacement: Int, Bool)
    /// Coup d'œil d'un adversaire : la carte s'incline vers lui, face cachée pour moi.
    case incliner(joueur: Int, emplacement: Int, Bool)
    /// Montrer (ou recacher) la face d'une carte d'une main. `face` est
    /// retenue (on s'en souvient) ; elle n'est jamais devinée.
    case montrer(joueur: Int, emplacement: Int, face: Carte?, Bool)
    /// Fin de manche : toutes les cartes de ce joueur sont retournées.
    case reveler(joueur: Int, cartes: [Carte])
}

/// Ce que l'écran dessine pour une carte.
public struct JetonAffiche: Identifiable, Equatable, Sendable {
    public let id: JetonID
    public let lieu: Lieu
    /// Face à dessiner (même cachée : sert au retournement 3D).
    public let face: Carte?
    /// Face tournée vers le haut.
    public let montree: Bool
    public let souleve: Bool
    public let incline: Bool
    /// Ordre de superposition.
    public let z: Double
}

public struct Plateau: Equatable, Sendable {
    public struct Tenue: Equatable, Sendable {
        public let joueur: Int
        public let jeton: JetonID
        public var montree: Bool
    }

    /// Le dessus est le dernier élément (comme dans le moteur).
    public private(set) var pioche: [JetonID]
    public private(set) var defausse: [JetonID]
    public private(set) var mains: [[JetonID]]
    public private(set) var tenue: Tenue?
    /// Faces connues du joueur, par jeton.
    public private(set) var faces: [JetonID: Carte] = [:]
    /// Cartes de main face visible (un instant, ou fin de manche).
    public private(set) var montrees: Set<JetonID> = []
    public private(set) var souleves: Set<JetonID> = []
    public private(set) var inclines: Set<JetonID> = []

    /// Toutes les cartes dans la pioche, mains vides : avant la distribution.
    public init(nombreJoueurs: Int) {
        pioche = Array(0..<52)
        defausse = []
        mains = Array(repeating: [], count: nombreJoueurs)
    }

    // MARK: - Lecture

    public func jeton(joueur: Int, emplacement: Int) -> JetonID? {
        guard mains.indices.contains(joueur), mains[joueur].indices.contains(emplacement) else { return nil }
        return mains[joueur][emplacement]
    }

    public func lieu(de id: JetonID) -> Lieu? {
        if let t = tenue, t.jeton == id { return .tenue(joueur: t.joueur) }
        if let i = pioche.lastIndex(of: id) { return .pioche(profondeur: pioche.count - 1 - i) }
        if let i = defausse.lastIndex(of: id) { return .defausse(profondeur: defausse.count - 1 - i, rang: i) }
        for (j, main) in mains.enumerated() {
            if let i = main.firstIndex(of: id) { return .main(joueur: j, emplacement: i) }
        }
        return nil
    }

    /// Les cartes à dessiner. Seules les `profondeurVisible` premières
    /// cartes de chaque tas sont rendues : les autres sont dessous.
    public func jetonsAffiches(profondeurVisible: Int = 3, toutMontrer: Bool = false) -> [JetonAffiche] {
        var r: [JetonAffiche] = []
        for (i, id) in pioche.enumerated() {
            let p = pioche.count - 1 - i
            guard p < profondeurVisible else { continue }
            r.append(affiche(id, .pioche(profondeur: p), montree: false, z: 10 + Double(i) * 0.01))
        }
        for (i, id) in defausse.enumerated() {
            let p = defausse.count - 1 - i
            guard p < profondeurVisible else { continue }
            r.append(affiche(id, .defausse(profondeur: p, rang: i), montree: true, z: 20 + Double(i) * 0.01))
        }
        for (j, main) in mains.enumerated() {
            for (i, id) in main.enumerated() {
                let montree = montrees.contains(id) || (toutMontrer && faces[id] != nil)
                let z = souleves.contains(id) ? 60 : 30 + Double(i) * 0.1
                r.append(affiche(id, .main(joueur: j, emplacement: i), montree: montree, z: z))
            }
        }
        if let t = tenue {
            r.append(affiche(t.jeton, .tenue(joueur: t.joueur), montree: t.montree, z: 80))
        }
        return r.sorted { $0.id < $1.id }
    }

    private func affiche(_ id: JetonID, _ lieu: Lieu, montree: Bool, z: Double) -> JetonAffiche {
        JetonAffiche(id: id, lieu: lieu, face: faces[id], montree: montree && faces[id] != nil,
                     souleve: souleves.contains(id), incline: inclines.contains(id), z: z)
    }

    // MARK: - Mouvements

    /// Applique un mouvement. Un mouvement impossible (pioche vide, place
    /// inconnue) est ignoré : l'écran ne doit jamais planter sur une
    /// animation, et les tests vérifient qu'il reste aligné sur le moteur.
    public mutating func appliquer(_ m: Mouvement) {
        switch m {
        case .distribuer(let j):
            guard mains.indices.contains(j), let id = pioche.popLast() else { return }
            mains[j].append(id)

        case .retournerSurDefausse(let carte):
            guard let id = pioche.popLast() else { return }
            faces[id] = carte
            defausse.append(id)

        case .prendre(let j, let source, let face):
            let id: JetonID?
            switch source {
            case .pioche: id = pioche.popLast()
            case .defausse: id = defausse.popLast()
            }
            guard let id else { return }
            if let face { faces[id] = face }
            tenue = Tenue(joueur: j, jeton: id, montree: source == .defausse)

        case .montrerTenue(let oui):
            guard var t = tenue else { return }
            t.montree = oui && faces[t.jeton] != nil
            tenue = t

        case .remplacer(let j, let emp, let ancienne):
            guard let t = tenue, let ancien = jeton(joueur: j, emplacement: emp) else { return }
            faces[ancien] = ancienne
            nettoyer(ancien)
            defausse.append(ancien)
            mains[j][emp] = t.jeton
            tenue = nil

        case .defausserTenue(let carte):
            guard let t = tenue else { return }
            faces[t.jeton] = carte
            defausse.append(t.jeton)
            tenue = nil

        case .echanger(let j, let emp, let adv, let sien):
            guard let a = jeton(joueur: j, emplacement: emp), let b = jeton(joueur: adv, emplacement: sien) else { return }
            mains[j][emp] = b
            mains[adv][sien] = a

        case .ecarter(let j, let emp, let carte):
            guard let id = jeton(joueur: j, emplacement: emp) else { return }
            faces[id] = carte
            nettoyer(id)
            mains[j].remove(at: emp)
            defausse.append(id)

        case .penalite(let j):
            guard mains.indices.contains(j), let id = pioche.popLast() else { return }
            mains[j].append(id)

        case .soulever(let j, let emp, let oui):
            guard let id = jeton(joueur: j, emplacement: emp) else { return }
            if oui { souleves.insert(id) } else { souleves.remove(id) }

        case .incliner(let j, let emp, let oui):
            guard let id = jeton(joueur: j, emplacement: emp) else { return }
            if oui { inclines.insert(id) } else { inclines.remove(id) }

        case .montrer(let j, let emp, let face, let oui):
            guard let id = jeton(joueur: j, emplacement: emp) else { return }
            if let face { faces[id] = face }
            if oui && faces[id] != nil { montrees.insert(id) } else { montrees.remove(id) }

        case .reveler(let j, let cartes):
            guard mains.indices.contains(j) else { return }
            for (i, id) in mains[j].enumerated() where i < cartes.count {
                faces[id] = cartes[i]
                montrees.insert(id)
            }
        }
    }

    public mutating func appliquer(_ mouvements: [Mouvement]) {
        for m in mouvements { appliquer(m) }
    }

    private mutating func nettoyer(_ id: JetonID) {
        montrees.remove(id)
        souleves.remove(id)
        inclines.remove(id)
    }
}
