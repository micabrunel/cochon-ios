// Une manche entière tient dans (config, graine, actions). C'est le format
// pensé pour le multijoueur : le serveur garde ce journal, le rejoue pour
// arbitrer, et peut le renvoyer à un téléphone qui se reconnecte.

public struct JournalPartie: Codable, Equatable, Sendable {
    public let config: ConfigPartie
    public let graine: UInt64
    public private(set) var actions: [Action]

    public init(config: ConfigPartie, graine: UInt64, actions: [Action] = []) {
        self.config = config
        self.graine = graine
        self.actions = actions
    }

    public mutating func ajouter(_ action: Action) { actions.append(action) }

    /// Rejoue toutes les actions depuis la donne. Lève l'erreur du premier
    /// coup illégal : un journal trafiqué est refusé.
    public func rejouer() throws -> EtatPartie {
        var etat = try Moteur.nouvellePartie(config: config, graine: graine)
        for a in actions { etat = try Moteur.appliquer(a, a: etat).etat }
        return etat
    }
}
