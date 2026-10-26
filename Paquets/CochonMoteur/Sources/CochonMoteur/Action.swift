// Les coups. Tous sont `Codable` : une partie se résume à
// (config, graine, liste d'actions) et se rejoue à l'identique ailleurs,
// sur un serveur ou chez un autre joueur.

public enum Coup: Codable, Equatable, Hashable, Sendable {
    /// Ouverture : regarder une de ses cartes (2 en tout).
    case regarder(emplacement: Int)
    case piocher(source: Source)
    /// Poser la carte tenue à cet emplacement ; l'ancienne va à la défausse.
    case remplacer(emplacement: Int)
    /// Défausser la carte tirée de la pioche (Valet et Dame : pouvoir).
    case defausserPiochee
    /// Valet : échanger à l'aveugle une de ses cartes avec celle d'un adversaire.
    case echangerValet(monEmplacement: Int, adversaire: Int, sonEmplacement: Int)
    /// Dame : regarder une de ses cartes.
    case regarderDame(emplacement: Int)
    /// Réflexe : écarter une carte du même rang que le dessus de la défausse.
    case reflexe(emplacement: Int)
    case passerReflexe
    case terminerTour
    /// Annoncer COCHON! à la place de terminer son tour.
    case annoncerCochon
}

public struct Action: Codable, Equatable, Hashable, Sendable {
    public let joueur: Int
    public let coup: Coup

    public init(joueur: Int, coup: Coup) {
        self.joueur = joueur
        self.coup = coup
    }
}

public enum ErreurMoteur: Error, Equatable, Sendable {
    case nombreJoueursInvalide
    case joueurInconnu
    case pasTonTour
    case coupHorsPhase
    case emplacementInvalide
    case adversaireInvalide
    case dejaRegardee
    case ouvertureDejaFaite
    case piocheVide
    case defausseVide
    /// Une carte prise à la défausse doit remplacer une carte de la main.
    case remplacementObligatoire
    case cochonDejaAnnonce
    case partieTerminee
}

/// Ce qui s'est passé, pour l'animation et le journal. Les événements ne
/// contiennent que des informations publiques : on peut les envoyer à tous
/// les joueurs tels quels. Les faces privées (carte tirée de la pioche,
/// carte regardée) se lisent dans la vue du joueur concerné.
public enum Evenement: Codable, Equatable, Sendable {
    case regardOuverture(joueur: Int, emplacement: Int)
    case debutDuJeu(premier: Int)
    case pioche(joueur: Int, source: Source, carteVisible: Carte?)
    case remplacement(joueur: Int, emplacement: Int, carteDefaussee: Carte)
    case defausse(joueur: Int, carte: Carte)
    /// Valet ou Dame sans cible possible (mains vides) : le pouvoir est perdu.
    case pouvoirSaute(joueur: Int, carte: Carte)
    case echangeValet(joueur: Int, monEmplacement: Int, adversaire: Int, sonEmplacement: Int)
    case regardDame(joueur: Int, emplacement: Int)
    case reflexeReussi(joueur: Int, emplacement: Int, carte: Carte)
    case reflexeRate(joueur: Int, emplacement: Int, carteMontree: Carte, penalite: Bool)
    case reflexePasse(joueur: Int)
    case tourSuivant(joueur: Int)
    case cochon(joueur: Int, toursRestants: Int)
    case finDeManche(scores: [Int])
}
