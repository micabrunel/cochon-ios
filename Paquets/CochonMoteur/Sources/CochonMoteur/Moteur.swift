// L'arbitre : fonctions pures (état, action) -> nouvel état. Il refuse tout
// coup illégal avec une `ErreurMoteur` et ne laisse jamais l'état à moitié
// modifié. Règles : « RÈGLES MICHAEL » (docs/REGLES.md).

public enum Moteur {

    // MARK: - Donne

    /// Mélange (graine), distribue 4 cartes à chacun, une par une, et
    /// retourne la première carte de la défausse.
    public static func nouvellePartie(config: ConfigPartie, graine: UInt64) throws -> EtatPartie {
        guard ConfigPartie.joueursPossibles.contains(config.nombreJoueurs) else {
            throw ErreurMoteur.nombreJoueursInvalide
        }
        guard (0..<config.nombreJoueurs).contains(config.premierJoueur) else {
            throw ErreurMoteur.joueurInconnu
        }
        var rng = GenerateurDeterministe(graine: graine)
        var paquet = rng.melanger(Carte.paquetComplet)
        let n = config.nombreJoueurs
        var mains = Array(repeating: [Carte](), count: n)
        // Comme à la table : une carte à chacun, quatre tours. Le dessus du
        // paquet est son dernier élément, comme la pioche.
        for _ in 0..<ConfigPartie.cartesParJoueur {
            for j in 0..<n { mains[j].append(paquet.removeLast()) }
        }
        let premiere = paquet.removeLast()
        // La défausse est face visible : tout le monde la connaît.
        let connues = Array(repeating: EnsembleCartes([premiere]), count: n)
        return EtatPartie(
            config: config, graine: graine,
            mains: mains, pioche: paquet, defausse: [premiere],
            actif: config.premierJoueur, phase: .ouverture,
            ouvertures: Array(repeating: [], count: n),
            connues: connues, cochonPar: nil, toursRestants: 0, numeroCoup: 0
        )
    }

    // MARK: - Coups

    /// Applique un coup. Lève une erreur si le coup est illégal.
    public static func appliquer(_ action: Action, a etat: EtatPartie) throws -> (etat: EtatPartie, evenements: [Evenement]) {
        var e = etat
        var ev: [Evenement] = []
        let j = action.joueur
        guard (0..<e.nombreJoueurs).contains(j) else { throw ErreurMoteur.joueurInconnu }
        if e.phase == .terminee { throw ErreurMoteur.partieTerminee }

        if case .regarder(let emp) = action.coup {
            try regarderOuverture(&e, &ev, joueur: j, emplacement: emp)
            e.numeroCoup += 1
            return (e, ev)
        }
        if e.phase == .ouverture { throw ErreurMoteur.coupHorsPhase }
        guard j == e.actif else { throw ErreurMoteur.pasTonTour }

        switch action.coup {
        case .regarder:
            throw ErreurMoteur.coupHorsPhase // traité plus haut

        case .piocher(let source):
            guard e.phase == .choixSource else { throw ErreurMoteur.coupHorsPhase }
            let carte: Carte
            switch source {
            case .pioche:
                guard let c = e.pioche.popLast() else { throw ErreurMoteur.piocheVide }
                carte = c
                e.connues[j].insert(c) // lui seul la voit
                ev.append(.pioche(joueur: j, source: .pioche, carteVisible: nil))
            case .defausse:
                guard let c = e.defausse.popLast() else { throw ErreurMoteur.defausseVide }
                carte = c // déjà connue de tous
                ev.append(.pioche(joueur: j, source: .defausse, carteVisible: c))
            }
            e.phase = .cartePiochee(carte: carte, source: source)

        case .remplacer(let emp):
            guard case .cartePiochee(let carte, _) = e.phase else { throw ErreurMoteur.coupHorsPhase }
            guard e.mains[j].indices.contains(emp) else { throw ErreurMoteur.emplacementInvalide }
            let ancienne = e.mains[j][emp]
            e.mains[j][emp] = carte
            versDefausse(&e, ancienne)
            ev.append(.remplacement(joueur: j, emplacement: emp, carteDefaussee: ancienne))
            // Pas de pouvoir : seul un Valet ou une Dame défaussé tout droit
            // depuis la pioche en donne un.
            e.phase = .reflexe

        case .defausserPiochee:
            guard case .cartePiochee(let carte, let source) = e.phase else { throw ErreurMoteur.coupHorsPhase }
            guard source == .pioche else { throw ErreurMoteur.remplacementObligatoire }
            versDefausse(&e, carte)
            ev.append(.defausse(joueur: j, carte: carte))
            e.phase = phaseApresDefausse(e, carte: carte, joueur: j, &ev)

        case .echangerValet(let mien, let adv, let sien):
            guard e.phase == .pouvoirValet else { throw ErreurMoteur.coupHorsPhase }
            guard adv != j, (0..<e.nombreJoueurs).contains(adv) else { throw ErreurMoteur.adversaireInvalide }
            guard e.mains[j].indices.contains(mien), e.mains[adv].indices.contains(sien) else {
                throw ErreurMoteur.emplacementInvalide
            }
            // À l'aveugle : personne n'apprend de face, les cartes changent
            // seulement de place (et chacun voit ce déplacement).
            let a = e.mains[j][mien]
            e.mains[j][mien] = e.mains[adv][sien]
            e.mains[adv][sien] = a
            ev.append(.echangeValet(joueur: j, monEmplacement: mien, adversaire: adv, sonEmplacement: sien))
            e.phase = .reflexe

        case .regarderDame(let emp):
            guard e.phase == .pouvoirDame else { throw ErreurMoteur.coupHorsPhase }
            guard e.mains[j].indices.contains(emp) else { throw ErreurMoteur.emplacementInvalide }
            e.connues[j].insert(e.mains[j][emp])
            ev.append(.regardDame(joueur: j, emplacement: emp))
            e.phase = .reflexe

        case .reflexe(let emp):
            guard e.phase == .reflexe else { throw ErreurMoteur.coupHorsPhase }
            guard e.mains[j].indices.contains(emp) else { throw ErreurMoteur.emplacementInvalide }
            guard let dessus = e.dessusDefausse else { throw ErreurMoteur.defausseVide }
            let carte = e.mains[j][emp]
            if carte.rang == dessus.rang {
                e.mains[j].remove(at: emp)
                versDefausse(&e, carte)
                ev.append(.reflexeReussi(joueur: j, emplacement: emp, carte: carte))
            } else {
                // La carte a été montrée pour vérifier : tous l'ont vue. Elle
                // reprend sa place, et une carte de pénalité, face cachée,
                // s'ajoute à la main (si la pioche n'est pas vide).
                for k in 0..<e.nombreJoueurs { e.connues[k].insert(carte) }
                let penalite = e.pioche.popLast()
                if let p = penalite { e.mains[j].append(p) }
                ev.append(.reflexeRate(joueur: j, emplacement: emp, carteMontree: carte, penalite: penalite != nil))
            }
            e.phase = .finDeTour

        case .passerReflexe:
            guard e.phase == .reflexe else { throw ErreurMoteur.coupHorsPhase }
            ev.append(.reflexePasse(joueur: j))
            e.phase = .finDeTour

        case .terminerTour:
            guard e.phase == .finDeTour else { throw ErreurMoteur.coupHorsPhase }
            if let c = e.cochonPar, j != c { e.toursRestants -= 1 }
            passerLaMain(&e, &ev)

        case .annoncerCochon:
            guard e.phase == .finDeTour else { throw ErreurMoteur.coupHorsPhase }
            guard e.cochonPar == nil else { throw ErreurMoteur.cochonDejaAnnonce }
            // Dernière orbite : chacun des autres joue encore une fois.
            e.cochonPar = j
            e.toursRestants = e.nombreJoueurs - 1
            ev.append(.cochon(joueur: j, toursRestants: e.toursRestants))
            passerLaMain(&e, &ev)
        }
        e.numeroCoup += 1
        return (e, ev)
    }

    // MARK: - Score

    /// Total de chaque main (le plus petit gagne).
    public static func scores(_ etat: EtatPartie) -> [Int] {
        etat.mains.map(total)
    }

    public static func total(_ main: [Carte]) -> Int {
        main.reduce(0) { $0 + $1.valeur }
    }

    /// Gagnant(s) de la manche : plus petit total, égalités comprises.
    public static func gagnants(_ etat: EtatPartie) -> [Int] {
        let s = scores(etat)
        guard let mini = s.min() else { return [] }
        return s.indices.filter { s[$0] == mini }
    }

    // MARK: - Étapes internes

    private static func regarderOuverture(_ e: inout EtatPartie, _ ev: inout [Evenement], joueur j: Int, emplacement: Int) throws {
        guard e.phase == .ouverture else { throw ErreurMoteur.coupHorsPhase }
        guard e.ouvertures[j].count < ConfigPartie.cartesRegardeesAuDebut else { throw ErreurMoteur.ouvertureDejaFaite }
        guard e.mains[j].indices.contains(emplacement) else { throw ErreurMoteur.emplacementInvalide }
        guard !e.ouvertures[j].contains(emplacement) else { throw ErreurMoteur.dejaRegardee }
        e.ouvertures[j].append(emplacement)
        e.connues[j].insert(e.mains[j][emplacement])
        ev.append(.regardOuverture(joueur: j, emplacement: emplacement))
        // En ligne, tout le monde regarde en même temps : le jeu démarre
        // quand le dernier a vu ses deux cartes.
        if e.ouvertures.allSatisfy({ $0.count == ConfigPartie.cartesRegardeesAuDebut }) {
            e.phase = .choixSource
            ev.append(.debutDuJeu(premier: e.actif))
        }
    }

    private static func versDefausse(_ e: inout EtatPartie, _ carte: Carte) {
        e.defausse.append(carte)
        for k in 0..<e.nombreJoueurs { e.connues[k].insert(carte) }
    }

    /// Après une défausse directe : pouvoir du Valet ou de la Dame s'il a
    /// une cible, sinon réflexe.
    private static func phaseApresDefausse(_ e: EtatPartie, carte: Carte, joueur j: Int, _ ev: inout [Evenement]) -> Phase {
        switch carte.rang {
        case .valet:
            let adversaireAvecCartes = (0..<e.nombreJoueurs).contains { $0 != j && !e.mains[$0].isEmpty }
            if !e.mains[j].isEmpty && adversaireAvecCartes { return .pouvoirValet }
            ev.append(.pouvoirSaute(joueur: j, carte: carte))
            return .reflexe
        case .dame:
            if !e.mains[j].isEmpty { return .pouvoirDame }
            ev.append(.pouvoirSaute(joueur: j, carte: carte))
            return .reflexe
        default:
            return .reflexe
        }
    }

    /// Fin du tour : manche finie (dernière orbite jouée ou pioche vide), ou
    /// joueur suivant. Celui qui a annoncé COCHON! ne rejoue pas.
    private static func passerLaMain(_ e: inout EtatPartie, _ ev: inout [Evenement]) {
        let orbiteFinie = e.cochonPar != nil && e.toursRestants <= 0
        if orbiteFinie || e.pioche.isEmpty {
            e.phase = .terminee
            // Tout est révélé.
            let toutes = EnsembleCartes(e.mains.joined())
            for k in 0..<e.nombreJoueurs { e.connues[k].formUnion(toutes) }
            ev.append(.finDeManche(scores: scores(e)))
            return
        }
        var suivant = (e.actif + 1) % e.nombreJoueurs
        if let c = e.cochonPar, suivant == c { suivant = (suivant + 1) % e.nombreJoueurs }
        e.actif = suivant
        e.phase = .choixSource
        ev.append(.tourSuivant(joueur: suivant))
    }
}
