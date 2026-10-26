// L'ordinateur. Il ne reçoit que la `VueJoueur` de son siège : une carte
// qu'il n'a jamais vue lui est inconnue (`nil`), il l'estime à partir des
// cartes encore jamais vues. Il ne peut pas tricher, par construction.
//
// Deux niveaux :
//   facile  oublie une partie de ce qu'il a vu, joue simple, se trompe parfois
//   malin   se souvient de tout ce qu'il a vu et compte les cartes

import CochonMoteur

public enum NiveauIA: String, Codable, CaseIterable, Sendable {
    case facile
    case malin
}

public struct Ordinateur: Sendable {
    public let niveau: NiveauIA
    /// Graine propre à cet ordinateur : même graine, même partie, mêmes
    /// décisions (rejouable, testable).
    public let graine: UInt64

    /// Part des cartes vues que le niveau facile oublie (sur 100).
    static let oubliFacile: UInt64 = 35
    /// Probabilité (sur 100) qu'il joue un coup au hasard.
    static let distractionFacile = 15

    public init(niveau: NiveauIA, graine: UInt64 = 0) {
        self.niveau = niveau
        self.graine = graine
    }

    /// Le coup choisi, toujours pris parmi `vue.coupsPossibles`.
    /// `nil` s'il n'a rien à jouer (pas son tour, ouverture déjà faite).
    public func choisir(_ vue: VueJoueur) -> Coup? {
        let possibles = vue.coupsPossibles
        guard !possibles.isEmpty else { return nil }
        var rng = GenerateurDeterministe(graine: GenerateurDeterministe.graine(
            graine, UInt64(vue.numeroCoup), UInt64(vue.moi)))
        if niveau == .facile, rng.uniforme(100) < Self.distractionFacile, vue.phase != .finDeTour {
            return possibles[rng.uniforme(possibles.count)]
        }
        let coup = decider(vue, Memoire(vue: vue, ordinateur: self), &rng)
        return possibles.contains(coup) ? coup : possibles[0]
    }

    // MARK: - Décisions

    private func decider(_ vue: VueJoueur, _ m: Memoire, _ rng: inout GenerateurDeterministe) -> Coup {
        let moi = vue.moi
        switch vue.phase {
        case .ouverture, .terminee:
            let p = vue.coupsPossibles
            return p[rng.uniforme(p.count)]

        case .choixSource:
            guard let dessus = vue.dessusDefausse else { return .piocher(source: .pioche) }
            if vue.cartesDansPioche == 0 { return .piocher(source: .defausse) }
            // Un Valet ou une Dame pris à la défausse vaut 10 et perd son pouvoir.
            let pouvoir = dessus.rang == .valet || dessus.rang == .dame
            let gain = m.pire(moi).valeur - Double(dessus.valeur)
            let prendre: Bool
            switch niveau {
            case .facile: prendre = !pouvoir && dessus.valeur <= 2 && gain > 0
            case .malin: prendre = !pouvoir && gain > 0 && (gain >= 3 || dessus.valeur <= 2)
            }
            return .piocher(source: prendre ? .defausse : .pioche)

        case .cartePiochee(let carteVue, let source):
            guard let carte = carteVue else { return .piocher(source: .pioche) }
            let pire = m.pire(moi)
            if source == .defausse { return .remplacer(emplacement: pire.emplacement) }
            let gain = pire.valeur - Double(carte.valeur)
            switch niveau {
            case .facile:
                return carte.valeur <= 5 && gain > 0 ? .remplacer(emplacement: pire.emplacement) : .defausserPiochee
            case .malin:
                if carte.rang == .dame, gain < 3, m.inconnues(moi) > 0 { return .defausserPiochee }
                if carte.rang == .valet, gain < 4, let ech = m.meilleurEchange(), ech.gain >= 2 { return .defausserPiochee }
                return gain > 0 ? .remplacer(emplacement: pire.emplacement) : .defausserPiochee
            }

        case .pouvoirValet:
            if niveau == .facile {
                let p = vue.coupsPossibles
                return p[rng.uniforme(p.count)]
            }
            guard let ech = m.meilleurEchange() else { return vue.coupsPossibles[0] }
            return .echangerValet(monEmplacement: ech.mien, adversaire: ech.adversaire, sonEmplacement: ech.sien)

        case .pouvoirDame:
            // Regarder d'abord une carte qu'il ne connaît pas.
            if let i = m.cartes[moi].firstIndex(where: { $0 == nil }) { return .regarderDame(emplacement: i) }
            return .regarderDame(emplacement: rng.uniforme(max(1, m.cartes[moi].count)))

        case .reflexe:
            // Seulement sur une carte dont il se souvient : sinon pénalité.
            if let dessus = vue.dessusDefausse,
               let i = m.cartes[moi].firstIndex(where: { $0?.rang == dessus.rang && ($0?.valeur ?? 0) > 0 }) {
                return .reflexe(emplacement: i)
            }
            return .passerReflexe

        case .finDeTour:
            guard vue.cochonPar == nil else { return .terminerTour }
            let mien = m.total(moi)
            let adversaires = (0..<vue.nombreJoueurs).filter { $0 != moi }.map { m.total($0) }.min() ?? 99
            let finProche = vue.cartesDansPioche <= vue.nombreJoueurs * 2
            let annoncer: Bool
            switch niveau {
            case .facile:
                annoncer = mien <= 4 || (finProche && mien < adversaires)
            case .malin:
                let inconnues = m.inconnues(moi)
                annoncer = (mien <= 5 && inconnues == 0)
                    || (mien <= 9 && inconnues <= 1 && mien + 3 <= adversaires)
                    || (finProche && mien < adversaires)
            }
            return annoncer ? .annoncerCochon : .terminerTour
        }
    }
}

/// Ce dont l'ordinateur se souvient, tiré de la vue (et amputé de ses
/// oublis s'il est facile).
struct Memoire {
    /// Pour chaque main, la carte dont il se souvient, sinon `nil`.
    let cartes: [[Carte?]]
    /// Valeur attendue d'une carte inconnue : moyenne des cartes jamais vues.
    let estimation: Double
    let moi: Int

    init(vue: VueJoueur, ordinateur: Ordinateur) {
        moi = vue.moi
        let jamaisVues = vue.cartesJamaisVues
        estimation = jamaisVues.isEmpty
            ? 360.0 / 52.0
            : Double(jamaisVues.reduce(0) { $0 + $1.valeur }) / Double(jamaisVues.count)
        if ordinateur.niveau == .facile {
            // Oubli stable : il oublie toujours les mêmes cartes au cours de
            // la partie, comme un joueur distrait, et pas au hasard à chaque coup.
            cartes = vue.mains.map { main in
                main.map { (carte: Carte?) -> Carte? in
                    guard let carte else { return nil }
                    let h = GenerateurDeterministe.graine(ordinateur.graine, UInt64(vue.moi), UInt64(carte.numero))
                    return h % 100 < Ordinateur.oubliFacile ? nil : carte
                }
            }
        } else {
            cartes = vue.mains
        }
    }

    func valeur(_ joueur: Int, _ emplacement: Int) -> Double {
        cartes[joueur][emplacement].map { Double($0.valeur) } ?? estimation
    }

    func total(_ joueur: Int) -> Double {
        cartes[joueur].indices.reduce(0) { $0 + valeur(joueur, $1) }
    }

    func inconnues(_ joueur: Int) -> Int {
        cartes[joueur].filter { $0 == nil }.count
    }

    /// Son emplacement le plus coûteux (connu ou estimé). À valeur égale,
    /// il préfère remplacer une carte connue.
    func pire(_ joueur: Int) -> (emplacement: Int, valeur: Double) {
        var meilleur = (emplacement: 0, valeur: -1.0)
        for i in cartes[joueur].indices {
            let v = valeur(joueur, i)
            if v > meilleur.valeur || (v == meilleur.valeur && cartes[joueur][i] != nil) {
                meilleur = (i, v)
            }
        }
        return meilleur
    }

    /// Échange de Valet le plus rentable : donner sa carte la plus chère
    /// contre la moins chère d'un adversaire.
    func meilleurEchange() -> (mien: Int, adversaire: Int, sien: Int, gain: Double)? {
        var meilleur: (mien: Int, adversaire: Int, sien: Int, gain: Double)?
        for adv in cartes.indices where adv != moi {
            for sien in cartes[adv].indices {
                for mien in cartes[moi].indices {
                    let g = valeur(moi, mien) - valeur(adv, sien)
                    if meilleur == nil || g > meilleur!.gain { meilleur = (mien, adv, sien, g) }
                }
            }
        }
        return meilleur
    }
}
