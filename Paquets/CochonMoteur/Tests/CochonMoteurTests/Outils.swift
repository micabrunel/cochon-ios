import XCTest
@testable import CochonMoteur

/// « 10C » → dix de cœur (codes : T trèfle, K carreau, C cœur, P pique).
func c(_ code: String) -> Carte {
    guard let carte = Carte(code: code) else { fatalError("code de carte inconnu : \(code)") }
    return carte
}

/// Un état fabriqué à la main pour tester une règle précise. La défausse
/// est connue de tous ; chacun connaît les cartes listées dans `connues`.
func etat(
    mains: [[String]],
    pioche: [String] = ["2T", "3T", "4T", "5T"],
    defausse: [String] = ["9K"],
    actif: Int = 0,
    phase: Phase = .choixSource,
    connues: [[String]]? = nil,
    cochonPar: Int? = nil,
    toursRestants: Int = 0
) -> EtatPartie {
    let n = mains.count
    let def = defausse.map(c)
    var connu = Array(repeating: EnsembleCartes(def), count: n)
    if let connues {
        for (j, liste) in connues.enumerated() { for code in liste { connu[j].insert(c(code)) } }
    }
    return EtatPartie(
        config: ConfigPartie(nombreJoueurs: n), graine: 0,
        mains: mains.map { $0.map(c) }, pioche: pioche.map(c), defausse: def,
        actif: actif, phase: phase,
        ouvertures: Array(repeating: [0, 1], count: n),
        connues: connu, cochonPar: cochonPar, toursRestants: toursRestants, numeroCoup: 0
    )
}

/// Joue un coup et remplace l'état.
@discardableResult
func jouer(_ e: inout EtatPartie, _ joueur: Int, _ coup: Coup, file: StaticString = #filePath, line: UInt = #line) throws -> [Evenement] {
    let r = try Moteur.appliquer(Action(joueur: joueur, coup: coup), a: e)
    e = r.etat
    return r.evenements
}

/// Vérifie qu'un coup est refusé avec l'erreur attendue, et que l'état n'a pas bougé.
func refuse(_ e: EtatPartie, _ joueur: Int, _ coup: Coup, _ attendu: ErreurMoteur, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertThrowsError(try Moteur.appliquer(Action(joueur: joueur, coup: coup), a: e), file: file, line: line) { err in
        XCTAssertEqual(err as? ErreurMoteur, attendu, file: file, line: line)
    }
}

/// Toutes les cartes de l'état : il y en a toujours exactement 52, chacune une fois.
func toutesLesCartes(_ e: EtatPartie) -> [Carte] {
    var t = e.mains.flatMap { $0 } + e.pioche + e.defausse
    if case .cartePiochee(let carte, _) = e.phase { t.append(carte) }
    return t
}
