// L'état complet d'une manche. C'est une valeur : on ne le modifie jamais,
// `Moteur.appliquer` en rend un nouveau. Hors du module, tous les champs
// sont en lecture seule.
//
// Cet état contient tout, y compris les cartes cachées : il ne quitte
// jamais l'arbitre (l'iPhone contre l'ordinateur, le serveur en ligne).
// Un joueur, humain ou ordinateur, ne reçoit que sa `VueJoueur`.

public enum Source: String, Codable, Sendable, CaseIterable {
    case pioche
    case defausse
}

public struct ConfigPartie: Codable, Equatable, Sendable {
    /// 2 à 4 joueurs.
    public var nombreJoueurs: Int
    /// Joueur qui commence (0 par défaut).
    public var premierJoueur: Int
    /// Minuteur par tour en secondes (15, 30, 60), `nil` = désactivé.
    /// Le moteur ne mesure pas le temps : c'est l'arbitre (application ou
    /// serveur) qui joue un coup par défaut à l'expiration.
    public var minuteur: Int?

    public static let cartesParJoueur = 4
    public static let cartesRegardeesAuDebut = 2
    public static let joueursPossibles = 2...4

    public init(nombreJoueurs: Int, premierJoueur: Int = 0, minuteur: Int? = nil) {
        self.nombreJoueurs = nombreJoueurs
        self.premierJoueur = premierJoueur
        self.minuteur = minuteur
    }
}

public enum Phase: Codable, Equatable, Sendable {
    /// Chacun regarde 2 de ses cartes, une par une, dans l'ordre qu'il veut.
    case ouverture
    /// Le joueur actif pioche dans la pioche ou prend la défausse.
    case choixSource
    /// Il tient une carte : la remplacer (obligatoire si prise à la défausse)
    /// ou la défausser (seulement si tirée de la pioche).
    case cartePiochee(carte: Carte, source: Source)
    /// Valet défaussé depuis la pioche : échange à l'aveugle.
    case pouvoirValet
    /// Dame défaussée depuis la pioche : regarder une de ses cartes.
    case pouvoirDame
    /// Après le coup : tenter un réflexe ou passer.
    case reflexe
    /// Terminer le tour ou annoncer COCHON!.
    case finDeTour
    /// Manche finie : tout est révélé, on compte.
    case terminee
}

public struct EtatPartie: Codable, Equatable, Sendable {
    public let config: ConfigPartie
    public let graine: UInt64
    /// Main de chaque joueur, emplacement par emplacement. Une main peut
    /// raccourcir (réflexe réussi) ou s'allonger (pénalité).
    public internal(set) var mains: [[Carte]]
    /// Le dessus de la pioche est le dernier élément.
    public internal(set) var pioche: [Carte]
    /// Le dessus de la défausse est le dernier élément.
    public internal(set) var defausse: [Carte]
    public internal(set) var actif: Int
    public internal(set) var phase: Phase
    /// Emplacements déjà regardés à l'ouverture, par joueur.
    public internal(set) var ouvertures: [[Int]]
    /// Cartes dont chaque joueur a vu la face. Les places étant publiques
    /// (chacun voit les cartes bouger), connaître la face suffit à savoir
    /// où elle est.
    public internal(set) var connues: [EnsembleCartes]
    /// Joueur qui a annoncé COCHON!, s'il y en a un.
    public internal(set) var cochonPar: Int?
    /// Tours de la dernière orbite encore à jouer.
    public internal(set) var toursRestants: Int
    /// Incrémenté à chaque coup accepté : un coup en ligne porte ce numéro,
    /// un coup en retard (déjà dépassé) est refusé.
    public internal(set) var numeroCoup: Int

    public var nombreJoueurs: Int { config.nombreJoueurs }
    public var dessusDefausse: Carte? { defausse.last }
    public var estTerminee: Bool { phase == .terminee }
}
