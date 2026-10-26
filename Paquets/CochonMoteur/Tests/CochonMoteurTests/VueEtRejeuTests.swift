import Foundation
import XCTest
@testable import CochonMoteur

/// Joue une manche entière au hasard parmi les coups possibles de la vue.
func partieAuHasard(joueurs: Int, graine: UInt64, verifier: ((EtatPartie) -> Void)? = nil) throws -> JournalPartie {
    let config = ConfigPartie(nombreJoueurs: joueurs, premierJoueur: Int(graine % UInt64(joueurs)))
    var journal = JournalPartie(config: config, graine: graine)
    var e = try Moteur.nouvellePartie(config: config, graine: graine)
    var rng = GenerateurDeterministe(graine: graine ^ 0xABCD)
    var garde = 0
    while e.phase != .terminee {
        garde += 1
        precondition(garde < 10_000, "la manche ne finit pas")
        // Pendant l'ouverture, n'importe qui peut jouer.
        let candidats = (0..<joueurs).filter { !e.vue(pour: $0).coupsPossibles.isEmpty }
        let j = candidats[rng.uniforme(candidats.count)]
        let coups = e.vue(pour: j).coupsPossibles
        var coup = coups[rng.uniforme(coups.count)]
        // Pas trop d'annonces immédiates, pour explorer de longues manches.
        if coup == .annoncerCochon, rng.uniforme(10) > 0 { coup = .terminerTour }
        let action = Action(joueur: j, coup: coup)
        e = try Moteur.appliquer(action, a: e).etat
        journal.ajouter(action)
        verifier?(e)
    }
    return journal
}

final class VueSansFuiteTests: XCTestCase {
    /// Deux états qui ne diffèrent que par des cartes qu'un joueur n'a jamais
    /// vues lui donnent exactement la même vue : rien ne fuit.
    func testUneCarteJamaisVueNeChangeRienALaVue() throws {
        let a = etat(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]],
                     pioche: ["9T", "10T"], connues: [["AT"], ["5T"]])
        var b = a
        // On échange deux cartes que le joueur 0 n'a jamais vues : le 5♣ de
        // l'adversaire (que celui-ci connaît) et le 10♣ de la pioche.
        b.mains[1][0] = c("10T")
        b.pioche[1] = c("5T")
        XCTAssertEqual(a.vue(pour: 0), b.vue(pour: 0))
        XCTAssertNotEqual(a.vue(pour: 1), b.vue(pour: 1))
    }

    func testOnVoitSaPropreCarteConnueEtCelleVueDeLAutre() {
        let e = etat(mains: [["AT", "2T"], ["5T", "6T"]], connues: [["2T", "6T"], []])
        let v = e.vue(pour: 0)
        XCTAssertEqual(v.mains, [[nil, c("2T")], [nil, c("6T")]])
        XCTAssertEqual(v.cartesDansPioche, 4)
    }

    func testCartesJamaisVues() {
        let e = etat(mains: [["AT", "2T"], ["5T", "6T"]], defausse: ["9K"], connues: [["2T"], []])
        let jamais = e.vue(pour: 0).cartesJamaisVues
        XCTAssertEqual(jamais.count, 50)
        XCTAssertFalse(jamais.contains(c("2T")))
        XCTAssertFalse(jamais.contains(c("9K")))
        XCTAssertTrue(jamais.contains(c("AT")))
    }

    /// Sur des centaines de manches, chaque coup proposé par la vue est
    /// accepté, les 52 cartes sont toujours là, et personne ne voit une
    /// carte qu'il n'a pas le droit de voir.
    func testInvariantsSurDesManchesAuHasard() throws {
        for graine in UInt64(1)...300 {
            let joueurs = 2 + Int(graine % 3)
            _ = try partieAuHasard(joueurs: joueurs, graine: graine) { e in
                XCTAssertEqual(Set(toutesLesCartes(e)).count, 52)
                XCTAssertEqual(toutesLesCartes(e).count, 52)
                guard e.phase != .terminee else { return }
                for j in 0..<joueurs {
                    let v = e.vue(pour: j)
                    for (p, main) in v.mains.enumerated() {
                        for (i, carte) in main.enumerated() where carte != nil {
                            XCTAssertTrue(e.connues[j].contains(e.mains[p][i]))
                        }
                    }
                    if case .cartePiochee(let carte?, .pioche) = v.phase { XCTAssertEqual(j, e.actif, "\(carte)") }
                }
            }
        }
    }
}

final class SerialisationTests: XCTestCase {
    let encodeur: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// Le format des coups est le contrat avec le futur serveur : on le fige.
    func testFormatJSONDesCoups() throws {
        let a = Action(joueur: 2, coup: .echangerValet(monEmplacement: 0, adversaire: 1, sonEmplacement: 3))
        let json = String(decoding: try encodeur.encode(a), as: UTF8.self)
        XCTAssertEqual(json, #"{"coup":{"echangerValet":{"adversaire":1,"monEmplacement":0,"sonEmplacement":3}},"joueur":2}"#)
        let p = String(decoding: try encodeur.encode(Action(joueur: 0, coup: .piocher(source: .defausse))), as: UTF8.self)
        XCTAssertEqual(p, #"{"coup":{"piocher":{"source":"defausse"}},"joueur":0}"#)
        let carte = String(decoding: try encodeur.encode([c("10C"), c("RP")]), as: UTF8.self)
        XCTAssertEqual(carte, #"["10C","RP"]"#)
    }

    func testToutesLesActionsAllerRetour() throws {
        let coups: [Coup] = [
            .regarder(emplacement: 1), .piocher(source: .pioche), .piocher(source: .defausse),
            .remplacer(emplacement: 3), .defausserPiochee,
            .echangerValet(monEmplacement: 0, adversaire: 2, sonEmplacement: 1),
            .regarderDame(emplacement: 2), .reflexe(emplacement: 0), .passerReflexe,
            .terminerTour, .annoncerCochon,
        ]
        for coup in coups {
            let a = Action(joueur: 1, coup: coup)
            XCTAssertEqual(try JSONDecoder().decode(Action.self, from: try encodeur.encode(a)), a)
        }
    }

    func testEtatEtVueAllerRetourEtJSONStable() throws {
        let journal = try partieAuHasard(joueurs: 3, graine: 77)
        let e = try journal.rejouer()
        let donnees = try encodeur.encode(e)
        XCTAssertEqual(try JSONDecoder().decode(EtatPartie.self, from: donnees), e)
        // Même état, même JSON (pas de Set dont l'ordre varie).
        XCTAssertEqual(try encodeur.encode(try journal.rejouer()), donnees)
        let v = e.vue(pour: 1)
        XCTAssertEqual(try JSONDecoder().decode(VueJoueur.self, from: try encodeur.encode(v)), v)
    }

    func testCarteInconnueRefuseeAuDecodage() {
        XCTAssertThrowsError(try JSONDecoder().decode([Carte].self, from: Data(#"["ZZ"]"#.utf8)))
    }
}

final class RejeuTests: XCTestCase {
    /// Une manche se rejoue à l'identique depuis (config, graine, actions),
    /// y compris après un passage par JSON : c'est ce que fera le serveur.
    func testRejeuIdentique() throws {
        for graine in UInt64(500)...540 {
            var final: EtatPartie?
            let journal = try partieAuHasard(joueurs: 2 + Int(graine % 3), graine: graine) { final = $0 }
            let transporte = try JSONDecoder().decode(JournalPartie.self, from: try JSONEncoder().encode(journal))
            XCTAssertEqual(try transporte.rejouer(), final)
        }
    }

    func testJournalTrafiqueRefuse() throws {
        var journal = try partieAuHasard(joueurs: 2, graine: 3)
        journal.ajouter(Action(joueur: 0, coup: .piocher(source: .pioche)))
        XCTAssertThrowsError(try journal.rejouer()) { XCTAssertEqual($0 as? ErreurMoteur, .partieTerminee) }
    }

    func testUnCoupRefuseNeModifiePasLEtat() throws {
        let e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 1)
        let copie = e
        _ = try? Moteur.appliquer(Action(joueur: 0, coup: .remplacer(emplacement: 0)), a: e)
        XCTAssertEqual(e, copie)
    }

    func testNumeroDeCoupAvanceAChaqueCoupAccepte() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 1)
        try jouer(&e, 1, .regarder(emplacement: 0))
        try jouer(&e, 0, .regarder(emplacement: 0))
        XCTAssertEqual(e.numeroCoup, 2)
    }
}
