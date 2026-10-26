// Les textes de la table, au tutoiement, phrases courtes. Testés ici pour
// que l'écran n'ait qu'à les afficher (et VoiceOver à les lire).

import CochonMoteur

public enum Textes {

    public static func nom(_ joueur: Int, moi: Int) -> String {
        joueur == moi ? "Toi" : "ORDI \(joueur)"
    }

    // MARK: - Cartes

    public static func nomRang(_ r: Rang) -> String {
        switch r {
        case .un: return "As"
        case .valet: return "Valet"
        case .dame: return "Dame"
        case .roi: return "Roi"
        default: return String(r.rawValue)
        }
    }

    public static func nomCouleur(_ c: Couleur) -> String {
        switch c {
        case .trefle: return "trèfle"
        case .carreau: return "carreau"
        case .coeur: return "cœur"
        case .pique: return "pique"
        }
    }

    /// « un Roi ♠ », « une Dame ♥ », « un 7 ♦ ».
    public static func avecArticle(_ carte: Carte) -> String {
        (carte.rang == .dame ? "une " : "un ") + nomRang(carte.rang) + " " + carte.couleur.symbole
    }

    /// « 0 point », « 1 point », « 30 points ». La valeur vient du moteur.
    public static func points(_ n: Int) -> String {
        n <= 1 ? "\(n) point" : "\(n) points"
    }

    /// Pour VoiceOver : « Roi de pique, 0 point ».
    public static func accessibilite(_ carte: Carte?) -> String {
        guard let carte else { return "Carte cachée" }
        return "\(nomRang(carte.rang)) de \(nomCouleur(carte.couleur)), \(points(carte.valeur))"
    }

    // MARK: - Bandeau

    public struct Banniere: Equatable, Sendable {
        public var titre: String
        public var detail: String?
        public var aMoi: Bool
    }

    /// `tour` = numéro du tour en cours, compté par l'écran.
    public static func banniere(_ vue: VueJoueur, tour: Int) -> Banniere {
        let detail = vue.cochonPar != nil ? "Dernier tour" : "Tour \(max(tour, 1))"
        switch vue.phase {
        case .ouverture:
            return Banniere(titre: "Regarde 2 cartes", detail: nil, aMoi: vue.regardsOuvertureRestants > 0)
        case .terminee:
            return Banniere(titre: "Fin de la manche", detail: nil, aMoi: false)
        default:
            if vue.actif == vue.moi { return Banniere(titre: "À toi !", detail: detail, aMoi: true) }
            return Banniere(titre: "\(nom(vue.actif, moi: vue.moi)) joue", detail: detail, aMoi: false)
        }
    }

    // MARK: - Légende et consignes

    /// Légende au-dessus de la carte que je tiens.
    public static func legendeTenue(_ vue: VueJoueur) -> String? {
        guard vue.estMonTour, case .cartePiochee(let c?, let source) = vue.phase else { return nil }
        if source == .defausse {
            return "Tu as pris \(avecArticle(c)) : choisis la carte à remplacer."
        }
        switch c.rang {
        case .valet: return "\(majuscule(avecArticle(c))) ! Défausse-le pour échanger une carte."
        case .dame: return "\(majuscule(avecArticle(c))) ! Défausse-la pour regarder une de tes cartes."
        default: return "Tu as pioché \(avecArticle(c)) : \(points(c.valeur)) !"
        }
    }

    /// Consigne courte du moment, ou `nil` s'il n'y a rien à dire.
    public static func consigne(_ vue: VueJoueur, valetMien: Int? = nil, attenteRemplacement: Bool = false) -> String? {
        switch vue.phase {
        case .ouverture:
            switch vue.regardsOuvertureRestants {
            case 2: return "Touche 2 de tes cartes pour les mémoriser."
            case 1: return "Encore une carte à regarder."
            default: return "Les ordis regardent leurs cartes…"
            }
        case .terminee:
            return nil
        default:
            break
        }
        guard vue.estMonTour else { return nil }
        switch vue.phase {
        case .choixSource: return "Pioche une carte, ou prends la défausse."
        case .cartePiochee(_, .pioche): return attenteRemplacement ? "Touche la carte à remplacer." : nil
        case .cartePiochee: return nil
        case .pouvoirValet:
            return valetMien == nil ? "Valet : touche une de tes cartes." : "Puis une carte d'un ordi."
        case .pouvoirDame: return "Dame : touche une carte pour la regarder."
        case .reflexe:
            guard let d = vue.dessusDefausse else { return "Fin du tour ?" }
            let (article, pronom) = d.rang == .dame ? ("Une", "la") : ("Un", "le")
            return "\(article) \(nomRang(d.rang)) dans ta main ? Touche-\(pronom). Sinon, fin du tour."
        case .finDeTour:
            return vue.cochonPar == nil ? "Fin du tour, ou COCHON! si ta main est basse." : "Fin du tour."
        default: return nil
        }
    }

    // MARK: - Annonces

    public static func annonce(_ a: Annonce, moi: Int) -> String {
        switch a {
        case .aToi: return "À toi !"
        case .valet(let j): return j == moi ? "Valet ! Échange une carte" : "\(nom(j, moi: moi)) : Valet !"
        case .dame(let j): return j == moi ? "Dame ! Regarde une carte" : "\(nom(j, moi: moi)) : Dame !"
        case .pouvoirPerdu: return "Pouvoir perdu"
        case .reflexeReussi(let j): return j == moi ? "Réflexe !" : "Réflexe de \(nom(j, moi: moi)) !"
        case .reflexeRate(let j): return j == moi ? "Raté !" : "\(nom(j, moi: moi)) se trompe !"
        case .plusUn: return "+1"
        case .cochon: return "COCHON!"
        }
    }

    /// Sous-titre de la grande annonce COCHON!.
    public static func sousTitreCochon(_ joueur: Int, moi: Int, toursRestants: Int) -> String {
        let qui = joueur == moi ? "Tu annonces" : "\(nom(joueur, moi: moi)) annonce"
        return "\(qui) : encore \(toursRestants) tour\(toursRestants > 1 ? "s" : "") et on compte."
    }

    // MARK: - Résultats

    public struct LigneResultat: Equatable, Sendable {
        public var joueur: Int
        public var nom: String
        public var score: Int
        public var gagnant: Bool
        public var aAnnonce: Bool
    }

    /// Classement de fin de manche (plus petit total d'abord), d'après les
    /// scores rendus par le moteur.
    public static func resultats(_ vue: VueJoueur) -> [LigneResultat] {
        guard let s = vue.scores, let mini = s.min() else { return [] }
        return s.indices
            .map { LigneResultat(joueur: $0, nom: nom($0, moi: vue.moi), score: s[$0],
                                 gagnant: s[$0] == mini, aAnnonce: vue.cochonPar == $0) }
            .sorted { ($0.score, $0.joueur) < ($1.score, $1.joueur) }
    }

    public static func titreResultats(_ vue: VueJoueur) -> String {
        let gagnants = resultats(vue).filter(\.gagnant)
        if gagnants.count > 1 {
            return gagnants.contains { $0.joueur == vue.moi } ? "Égalité, tu gagnes aussi !" : "Égalité !"
        }
        guard let g = gagnants.first else { return "Fin de la manche" }
        return g.joueur == vue.moi ? "Tu gagnes la manche !" : "\(g.nom) gagne la manche"
    }

    private static func majuscule(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }
}
