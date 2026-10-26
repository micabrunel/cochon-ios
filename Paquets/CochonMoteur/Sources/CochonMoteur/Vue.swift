// Ce qu'un joueur a le droit de savoir. C'est la seule chose que reçoivent
// l'écran du joueur, l'ordinateur et, en ligne, chaque téléphone : une
// carte que le joueur n'a jamais vue y est `nil`, impossible à tricher.

public enum VuePhase: Codable, Equatable, Sendable {
    case ouverture
    case choixSource
    /// `carte` est `nil` pour les autres joueurs quand elle vient de la pioche.
    case cartePiochee(carte: Carte?, source: Source)
    case pouvoirValet
    case pouvoirDame
    case reflexe
    case finDeTour
    case terminee
}

public struct VueJoueur: Codable, Equatable, Sendable {
    public let moi: Int
    public let nombreJoueurs: Int
    public let actif: Int
    public let phase: VuePhase
    /// Toutes les mains, emplacement par emplacement : la face si je l'ai
    /// vue, sinon `nil`.
    public let mains: [[Carte?]]
    /// La défausse entière est publique (chaque carte y a été posée face visible).
    public let defausse: [Carte]
    public let cartesDansPioche: Int
    /// Cartes qu'il me reste à regarder à l'ouverture.
    public let regardsOuvertureRestants: Int
    public let emplacementsRegardesOuverture: [Int]
    public let cochonPar: Int?
    public let toursRestants: Int
    public let numeroCoup: Int
    /// Scores, seulement quand la manche est finie.
    public let scores: [Int]?

    public init(moi: Int, nombreJoueurs: Int, actif: Int, phase: VuePhase, mains: [[Carte?]],
                defausse: [Carte], cartesDansPioche: Int, regardsOuvertureRestants: Int = 0,
                emplacementsRegardesOuverture: [Int] = [], cochonPar: Int? = nil, toursRestants: Int = 0,
                numeroCoup: Int = 0, scores: [Int]? = nil) {
        self.moi = moi
        self.nombreJoueurs = nombreJoueurs
        self.actif = actif
        self.phase = phase
        self.mains = mains
        self.defausse = defausse
        self.cartesDansPioche = cartesDansPioche
        self.regardsOuvertureRestants = regardsOuvertureRestants
        self.emplacementsRegardesOuverture = emplacementsRegardesOuverture
        self.cochonPar = cochonPar
        self.toursRestants = toursRestants
        self.numeroCoup = numeroCoup
        self.scores = scores
    }

    public var maMain: [Carte?] { mains[moi] }
    public var dessusDefausse: Carte? { defausse.last }
    public var estMonTour: Bool { actif == moi && phase != .ouverture && phase != .terminee }

    /// Carte que je tiens, si c'est mon tour et que j'en tiens une.
    public var cartePiochee: Carte? {
        if case .cartePiochee(let c, _) = phase, actif == moi { return c }
        return nil
    }

    /// Cartes dont je n'ai vu la face nulle part : celles qui peuvent être
    /// sous un dos de carte ou dans la pioche. Sert à l'ordinateur pour
    /// estimer une carte inconnue, sans tricher.
    public var cartesJamaisVues: [Carte] {
        var vues = EnsembleCartes(defausse)
        for main in mains { for c in main { if let c { vues.insert(c) } } }
        if case .cartePiochee(let c?, _) = phase { vues.insert(c) }
        return Carte.paquetComplet.filter { !vues.contains($0) }
    }

    /// Coups que je peux jouer maintenant (l'arbitre accepte chacun d'eux).
    public var coupsPossibles: [Coup] {
        let maMain = mains[moi]
        switch phase {
        case .ouverture:
            guard regardsOuvertureRestants > 0 else { return [] }
            return maMain.indices.filter { !emplacementsRegardesOuverture.contains($0) }.map { .regarder(emplacement: $0) }
        case .terminee:
            return []
        default:
            break
        }
        guard actif == moi else { return [] }
        switch phase {
        case .choixSource:
            var c: [Coup] = []
            if cartesDansPioche > 0 { c.append(.piocher(source: .pioche)) }
            if !defausse.isEmpty { c.append(.piocher(source: .defausse)) }
            return c
        case .cartePiochee(_, let source):
            var c: [Coup] = maMain.indices.map { .remplacer(emplacement: $0) }
            if source == .pioche { c.append(.defausserPiochee) }
            return c
        case .pouvoirValet:
            var c: [Coup] = []
            for adv in 0..<nombreJoueurs where adv != moi {
                for mien in maMain.indices {
                    for sien in mains[adv].indices {
                        c.append(.echangerValet(monEmplacement: mien, adversaire: adv, sonEmplacement: sien))
                    }
                }
            }
            return c
        case .pouvoirDame:
            return maMain.indices.map { .regarderDame(emplacement: $0) }
        case .reflexe:
            return maMain.indices.map { .reflexe(emplacement: $0) } + [.passerReflexe]
        case .finDeTour:
            return cochonPar == nil ? [.terminerTour, .annoncerCochon] : [.terminerTour]
        case .ouverture, .terminee:
            return []
        }
    }
}

extension EtatPartie {
    /// La vue d'un joueur sur cet état.
    public func vue(pour joueur: Int) -> VueJoueur {
        let connu = connues[joueur]
        let fini = phase == .terminee
        let vuePhase: VuePhase
        switch phase {
        case .ouverture: vuePhase = .ouverture
        case .choixSource: vuePhase = .choixSource
        case .cartePiochee(let c, let s):
            vuePhase = .cartePiochee(carte: (joueur == actif || s == .defausse) ? c : nil, source: s)
        case .pouvoirValet: vuePhase = .pouvoirValet
        case .pouvoirDame: vuePhase = .pouvoirDame
        case .reflexe: vuePhase = .reflexe
        case .finDeTour: vuePhase = .finDeTour
        case .terminee: vuePhase = .terminee
        }
        return VueJoueur(
            moi: joueur,
            nombreJoueurs: nombreJoueurs,
            actif: actif,
            phase: vuePhase,
            mains: mains.map { main in main.map { (fini || connu.contains($0)) ? $0 : nil } },
            defausse: defausse,
            cartesDansPioche: pioche.count,
            regardsOuvertureRestants: phase == .ouverture
                ? ConfigPartie.cartesRegardeesAuDebut - ouvertures[joueur].count : 0,
            emplacementsRegardesOuverture: ouvertures[joueur],
            cochonPar: cochonPar,
            toursRestants: toursRestants,
            numeroCoup: numeroCoup,
            scores: fini ? Moteur.scores(self) : nil
        )
    }
}
