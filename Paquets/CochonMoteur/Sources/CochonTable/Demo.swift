// Mode démo : ouvrir directement un écran dans un état réaliste, et
// toujours le même, pour les captures d'écran automatiques
// (scripts/captures-ecrans.sh, flux CI « Captures »).
//
// Lancement : `-ecran <nom>` (voir `EcranDemo`), et `-graine <n>` en option.
//
// Aucune règle ici non plus : la partie est jouée par le vrai moteur. Le
// siège du joueur est tenu par l'ordinateur malin, avec quelques choix
// imposés pour arriver à la situation voulue (défausser un Valet pour son
// pouvoir, tenter un réflexe, attendre le 3e tour pour annoncer COCHON!).
// Les graines sont essayées une à une à partir de la graine demandée : la
// première partie qui mène à l'écran est retenue. Même graine, même écran.

import CochonIA
import CochonMoteur

/// Les écrans que le mode démo sait ouvrir, dans l'ordre des captures.
public enum EcranDemo: String, CaseIterable, Sendable {
    case accueil
    case regles
    case parametres
    /// Ouverture : je regarde ma première carte.
    case regard
    /// Mon tour : pioche ou défausse.
    case monTour = "mon-tour"
    /// Je tiens une carte de la pioche : Remplacer / Défausser.
    case cartePiochee = "carte-piochee"
    /// Valet défaussé : ma carte est choisie, reste celle d'un ordi.
    case valet
    /// Dame défaussée : ma carte se retourne.
    case dame
    /// Réflexe réussi.
    case reflexe
    /// Réflexe raté : carte de pénalité et « +1 ».
    case penalite
    /// Un ordinateur joue (il tient la carte qu'il vient de piocher).
    case tourOrdi = "tour-ordi"
    /// J'annonce COCHON!.
    case cochon
    /// Un ordi a annoncé COCHON! : c'est mon dernier tour.
    case derniereOrbite = "derniere-orbite"
    /// Fin de manche : classement.
    case resultats
    /// Menu de la partie (pause), ouvert sur mon tour.
    case menu

    /// Faux pour l'accueil et ses feuilles (règles, paramètres) : rien à jouer.
    public var surLaTable: Bool {
        switch self {
        case .accueil, .regles, .parametres: return false
        default: return true
        }
    }

    /// Vrai pour les seuls écrans où quelqu'un a déjà annoncé COCHON! ;
    /// partout ailleurs, la scène retenue n'a aucune annonce.
    public var apresUneAnnonce: Bool {
        switch self {
        case .cochon, .derniereOrbite, .resultats: return true
        default: return false
        }
    }
}

/// Une table figée, prête à dessiner.
public struct SceneDemo: Sendable {
    public let ecran: EcranDemo
    /// Graine de la partie retenue (la première qui mène à l'écran).
    public let graine: UInt64
    public let arbitre: Arbitre
    public let plateau: Plateau
    public let compteur: CompteurTours
    /// Annonces à laisser à l'écran (bulle, « +1 », COCHON!).
    public let annonces: [Annonce]
    /// Valet : ma carte déjà choisie.
    public let valetMien: Int?
    /// Une animation est en cours (ordinateurs, regard) : pas de commandes.
    public let occupe: Bool
    public let resultats: Bool

    public var vue: VueJoueur { arbitre.vue }
}

/// Arguments de lancement lus par l'app.
public struct LancementDemo: Equatable, Sendable {
    public var ecran: EcranDemo?
    /// Nom passé à `-ecran` qui ne correspond à aucun écran.
    public var nomInconnu: String?
    public var graine: UInt64

    public init(ecran: EcranDemo? = nil, nomInconnu: String? = nil, graine: UInt64 = Demo.graineParDefaut) {
        self.ecran = ecran
        self.nomInconnu = nomInconnu
        self.graine = graine
    }

    public var actif: Bool { ecran != nil || nomInconnu != nil }
}

public enum Demo {
    public static let graineParDefaut: UInt64 = 2026
    public static let nombreJoueurs = 4
    /// Graines essayées avant d'abandonner (une scène introuvable s'affiche
    /// en clair à l'écran : la capture le montre).
    public static let essais = 300
    static let coupsMax = 600

    /// Lit `-ecran <nom>` et `-graine <n>` dans les arguments du processus.
    public static func lancement(arguments: [String]) -> LancementDemo {
        func valeur(_ nom: String) -> String? {
            guard let i = arguments.firstIndex(of: "-" + nom), arguments.indices.contains(i + 1) else { return nil }
            return arguments[i + 1]
        }
        let nom = valeur("ecran")
        let ecran = nom.flatMap(EcranDemo.init(rawValue:))
        return LancementDemo(ecran: ecran, nomInconnu: ecran == nil ? nom : nil,
                             graine: valeur("graine").flatMap { UInt64($0) } ?? graineParDefaut)
    }

    /// La scène de cet écran, ou `nil` (écran hors table, ou aucune des
    /// graines essayées n'y mène).
    public static func scene(_ ecran: EcranDemo, graine: UInt64 = graineParDefaut,
                             niveau: NiveauIA = .malin) -> SceneDemo? {
        guard ecran.surLaTable else { return nil }
        for k in 0..<UInt64(essais) {
            if let s = try? partie(ecran, graine: graine &+ k, niveau: niveau) { return s }
        }
        return nil
    }

    // MARK: - Partie jouée jusqu'à l'écran voulu

    /// Comment figer la table une fois la situation atteinte.
    struct Arrivee {
        /// Étapes du dernier coup à jouer (`nil` = toutes) : on s'arrête au
        /// milieu d'une animation (carte retournée).
        var etapes: Int?
        /// Annonces à garder (`nil` = celles des étapes jouées, sans « À toi ! »).
        var annonces: [Annonce]?
        var occupe: Bool
        var resultats = false
    }

    static func partie(_ ecran: EcranDemo, graine: UInt64, niveau: NiveauIA) throws -> SceneDemo? {
        let n = nombreJoueurs
        var arbitre = try Arbitre(config: ConfigPartie(nombreJoueurs: n), niveau: niveau, graine: graine)
        let moi = arbitre.moi
        let joueur = Ordinateur(niveau: .malin, graine: graine &+ 1_000)
        let rythme = Rythme()
        var plateau = Plateau(nombreJoueurs: n)
        for e in Choregraphie.distribution(nombreJoueurs: n, premiere: arbitre.vue.defausse[0], rythme: rythme) {
            plateau.appliquer(e.mouvements)
        }
        var compteur = CompteurTours(nombreJoueurs: n)

        for _ in 0..<coupsMax {
            let action: Action
            if let a = arbitre.prochainCoupOrdinateur() {
                action = a
            } else if let c = coupDuJoueur(ecran, arbitre: arbitre, joueur: joueur, tour: compteur.tour) {
                action = Action(joueur: moi, coup: c)
            } else {
                return nil // manche finie sans passer par l'écran voulu
            }
            let evenements = action.joueur == moi ? try arbitre.jouer(action.coup) : try arbitre.jouerOrdinateur(action)
            compteur.noter(evenements)
            let vue = arbitre.vue
            let etapes = Choregraphie.etapes(pour: evenements, moi: moi, vueApres: vue, rythme: rythme)

            guard let fin = arrivee(ecran, action: action, evenements: evenements, vue: vue,
                                    etat: arbitre.etat, tour: compteur.tour) else {
                for e in etapes { plateau.appliquer(e.mouvements) }
                continue
            }
            let jouees = fin.etapes.map { Array(etapes.prefix($0)) } ?? etapes
            for e in jouees { plateau.appliquer(e.mouvements) }
            var valetMien: Int?
            if ecran == .valet {
                if case .echangerValet(let mien, _, _)? = joueur.choisir(vue) { valetMien = mien } else { valetMien = 0 }
                plateau.appliquer(.soulever(joueur: moi, emplacement: valetMien!, true))
            }
            return SceneDemo(ecran: ecran, graine: graine, arbitre: arbitre, plateau: plateau, compteur: compteur,
                             annonces: fin.annonces ?? jouees.compactMap(\.annonce).filter { $0 != .aToi },
                             valetMien: valetMien, occupe: fin.occupe, resultats: fin.resultats)
        }
        return nil
    }

    /// Le coup du joueur : celui de l'ordinateur malin, sauf les quelques
    /// choix imposés qui mènent à l'écran voulu.
    static func coupDuJoueur(_ ecran: EcranDemo, arbitre: Arbitre, joueur: Ordinateur, tour: Int) -> Coup? {
        let vue = arbitre.vue
        guard !vue.coupsPossibles.isEmpty else { return nil }
        let main = arbitre.etat.mains[arbitre.moi]

        if vue.estMonTour, case .cartePiochee(let c?, .pioche) = vue.phase,
           (ecran == .valet && c.rang == .valet) || (ecran == .dame && c.rang == .dame) {
            return .defausserPiochee
        }
        if vue.estMonTour, vue.phase == .reflexe, tour >= 2, let dessus = vue.dessusDefausse {
            if ecran == .reflexe, let i = main.firstIndex(where: { $0.rang == dessus.rang }) {
                return .reflexe(emplacement: i)
            }
            if ecran == .penalite, vue.cartesDansPioche > 0, let i = main.firstIndex(where: { $0.rang != dessus.rang }) {
                return .reflexe(emplacement: i)
            }
        }
        let annonceVoulue = (ecran == .cochon || ecran == .resultats) && tour >= 3
        if annonceVoulue, vue.estMonTour, vue.cochonPar == nil, Moteur.total(main) <= 12 {
            if vue.phase == .reflexe { return .passerReflexe }
            if vue.phase == .finDeTour { return .annoncerCochon }
        }
        guard let coup = joueur.choisir(vue) else { return nil }
        // Pas de COCHON! du joueur ailleurs : la manche finirait trop tôt.
        if coup == .annoncerCochon && !annonceVoulue { return .terminerTour }
        return coup
    }

    /// La situation voulue est-elle atteinte après ce coup ?
    static func arrivee(_ ecran: EcranDemo, action: Action, evenements: [Evenement], vue: VueJoueur,
                        etat: EtatPartie, tour: Int) -> Arrivee? {
        let moi = vue.moi
        let parMoi = action.joueur == moi
        // Personne n'a encore annoncé COCHON!, sauf sur les écrans qui le
        // montrent : sinon la bannière dit « Dernier tour » et le bouton
        // COCHON! est éteint pour une autre raison que celle de l'écran.
        if !ecran.apresUneAnnonce && vue.cochonPar != nil { return nil }
        switch ecran {
        case .accueil, .regles, .parametres:
            return nil

        case .regard:
            guard parMoi, case .regarder = action.coup, vue.regardsOuvertureRestants == 1 else { return nil }
            // Soulevée puis retournée : on s'arrête carte visible.
            return Arrivee(etapes: 2, occupe: true)

        case .monTour, .menu:
            guard vue.estMonTour, vue.phase == .choixSource, vue.cochonPar == nil, tour >= 3 else { return nil }
            return Arrivee(occupe: false)

        case .cartePiochee:
            guard parMoi, action.coup == .piocher(source: .pioche), tour >= 2,
                  let c = vue.cartePiochee, c.rang != .valet, c.rang != .dame else { return nil }
            return Arrivee(occupe: false)

        case .valet:
            guard parMoi, action.coup == .defausserPiochee, vue.phase == .pouvoirValet else { return nil }
            return Arrivee(occupe: false)

        case .dame:
            guard parMoi, case .regarderDame = action.coup else { return nil }
            return Arrivee(etapes: 2, annonces: [.dame(joueur: moi)], occupe: true)

        case .reflexe:
            guard parMoi, tour >= 2,
                  evenements.contains(where: { if case .reflexeReussi = $0 { return true } else { return false } })
            else { return nil }
            return Arrivee(occupe: false)

        case .penalite:
            guard parMoi, tour >= 2,
                  evenements.contains(where: { if case .reflexeRate(_, _, _, true) = $0 { return true } else { return false } })
            else { return nil }
            return Arrivee(occupe: false)

        case .tourOrdi:
            guard !parMoi, action.coup == .piocher(source: .pioche), tour >= 2, vue.cochonPar == nil else { return nil }
            return Arrivee(occupe: true)

        case .cochon:
            guard parMoi, action.coup == .annoncerCochon else { return nil }
            return Arrivee(occupe: true)

        case .derniereOrbite:
            guard let c = vue.cochonPar, c != moi, vue.estMonTour, vue.phase == .choixSource else { return nil }
            return Arrivee(occupe: false)

        case .resultats:
            guard vue.phase == .terminee, vue.cochonPar == moi, Moteur.gagnants(etat) == [moi] else { return nil }
            return Arrivee(annonces: [], occupe: false, resultats: true)
        }
    }
}
