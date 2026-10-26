import XCTest
@testable import CochonMoteur

final class DonneTests: XCTestCase {
    func testQuatreCartesCacheesParJoueurEtUneDefausse() throws {
        for n in 2...4 {
            let e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: n), graine: 9)
            XCTAssertEqual(e.mains.count, n)
            XCTAssertTrue(e.mains.allSatisfy { $0.count == 4 })
            XCTAssertEqual(e.defausse.count, 1)
            XCTAssertEqual(e.pioche.count, 52 - 4 * n - 1)
            XCTAssertEqual(e.phase, .ouverture)
            XCTAssertEqual(Set(toutesLesCartes(e)).count, 52)
        }
    }

    func testDeuxAQuatreJoueursSeulement() {
        for n in [0, 1, 5] {
            XCTAssertThrowsError(try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: n), graine: 1)) {
                XCTAssertEqual($0 as? ErreurMoteur, .nombreJoueursInvalide)
            }
        }
        XCTAssertThrowsError(try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2, premierJoueur: 2), graine: 1))
    }

    func testPersonneNeConnaitSesCartesAuDepart() throws {
        let e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 3), graine: 5)
        for j in 0..<3 {
            XCTAssertTrue(e.vue(pour: j).mains.allSatisfy { $0.allSatisfy { $0 == nil } })
            XCTAssertEqual(e.vue(pour: j).defausse, e.defausse, "la défausse est face visible")
        }
    }

    func testPremierJoueurChoisi() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 3, premierJoueur: 2), graine: 5)
        for j in 0..<3 { try jouer(&e, j, .regarder(emplacement: 0)); try jouer(&e, j, .regarder(emplacement: 3)) }
        XCTAssertEqual(e.actif, 2)
        XCTAssertEqual(e.phase, .choixSource)
    }
}

final class OuvertureTests: XCTestCase {
    func testOnRegardeDeuxCartesUneParUne() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 11)
        try jouer(&e, 0, .regarder(emplacement: 2))
        XCTAssertEqual(e.vue(pour: 0).maMain.compactMap { $0 }, [e.mains[0][2]])
        XCTAssertEqual(e.vue(pour: 0).regardsOuvertureRestants, 1)
        try jouer(&e, 0, .regarder(emplacement: 0))
        XCTAssertEqual(e.vue(pour: 0).maMain.compactMap { $0 }.count, 2)
        XCTAssertNil(e.vue(pour: 0).maMain[1])
        XCTAssertNil(e.vue(pour: 0).maMain[3])
        // L'adversaire n'a rien appris.
        XCTAssertTrue(e.vue(pour: 1).mains[0].allSatisfy { $0 == nil })
    }

    func testPasTroisCartesNiDeuxFoisLaMeme() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 11)
        try jouer(&e, 0, .regarder(emplacement: 1))
        refuse(e, 0, .regarder(emplacement: 1), .dejaRegardee)
        refuse(e, 0, .regarder(emplacement: 4), .emplacementInvalide)
        try jouer(&e, 0, .regarder(emplacement: 3))
        refuse(e, 0, .regarder(emplacement: 0), .ouvertureDejaFaite)
    }

    func testLeJeuCommenceQuandToutLeMondeARegarde() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 3), graine: 11)
        // Ordre libre : en ligne, chacun regarde en même temps.
        try jouer(&e, 2, .regarder(emplacement: 0))
        try jouer(&e, 0, .regarder(emplacement: 0))
        try jouer(&e, 0, .regarder(emplacement: 1))
        refuse(e, 0, .piocher(source: .pioche), .coupHorsPhase)
        try jouer(&e, 1, .regarder(emplacement: 2))
        try jouer(&e, 1, .regarder(emplacement: 3))
        XCTAssertEqual(e.phase, .ouverture)
        let ev = try jouer(&e, 2, .regarder(emplacement: 1))
        XCTAssertEqual(e.phase, .choixSource)
        XCTAssertEqual(ev.last, .debutDuJeu(premier: 0))
    }

    func testRegarderApresOuvertureRefuse() {
        let e = etat(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]])
        refuse(e, 0, .regarder(emplacement: 2), .coupHorsPhase)
    }
}
