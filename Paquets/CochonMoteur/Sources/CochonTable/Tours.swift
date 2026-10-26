// Numéro du tour affiché dans le bandeau (« Tour 6 ») : un tour = chaque
// joueur a joué une fois. Compté à partir des événements publics.

import CochonMoteur

public struct CompteurTours: Equatable, Sendable {
    public let nombreJoueurs: Int
    private var passages = 0

    public init(nombreJoueurs: Int) { self.nombreJoueurs = max(nombreJoueurs, 1) }

    /// Tour en cours, à partir de 1.
    public var tour: Int { 1 + passages / nombreJoueurs }

    public mutating func noter(_ evenements: [Evenement]) {
        for e in evenements {
            if case .tourSuivant = e { passages += 1 }
        }
    }
}
