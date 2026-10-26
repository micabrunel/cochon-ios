import XCTest
@testable import CochonMoteur

/// Joue un tour complet sans rien changer : pioche, défausse, passe le réflexe.
func tourNeutre(_ e: inout EtatPartie, cochon: Bool = false) throws {
    let j = e.actif
    try jouer(&e, j, .piocher(source: .pioche))
    try jouer(&e, j, .defausserPiochee)
    if e.phase == .pouvoirDame { try jouer(&e, j, .regarderDame(emplacement: 0)) }
    if e.phase == .pouvoirValet {
        let adv = (j + 1) % e.nombreJoueurs
        try jouer(&e, j, .echangerValet(monEmplacement: 0, adversaire: adv, sonEmplacement: 0))
    }
    try jouer(&e, j, .passerReflexe)
    try jouer(&e, j, cochon ? .annoncerCochon : .terminerTour)
}

let pioche20 = ["AC", "2C", "3C", "4C", "5C", "6C", "7C", "8C", "9C", "10C",
                "AK", "2K", "3K", "4K", "5K", "6K", "7K", "8K", "9P", "10K"]

final class TourSuivantTests: XCTestCase {
    func testLaMainPasseAuSuivantEnRond() throws {
        var e = etat(mains: [["AT"], ["2T"], ["3T"]], pioche: pioche20)
        try tourNeutre(&e); XCTAssertEqual(e.actif, 1)
        try tourNeutre(&e); XCTAssertEqual(e.actif, 2)
        try tourNeutre(&e); XCTAssertEqual(e.actif, 0)
        XCTAssertEqual(e.phase, .choixSource)
    }

    func testTerminerSonTourAvantLaFinRefuse() throws {
        var e = etat(mains: [["AT"], ["2T"]], pioche: pioche20)
        refuse(e, 0, .terminerTour, .coupHorsPhase)
        refuse(e, 0, .annoncerCochon, .coupHorsPhase)
        try jouer(&e, 0, .piocher(source: .pioche))
        refuse(e, 0, .annoncerCochon, .coupHorsPhase)
    }

    func testPiocheEpuiseeFinitLaManche() throws {
        var e = etat(mains: [["AT"], ["2T"]], pioche: ["5C"])
        let ev = try { () throws -> [Evenement] in
            try jouer(&e, 0, .piocher(source: .pioche))
            try jouer(&e, 0, .defausserPiochee)
            try jouer(&e, 0, .passerReflexe)
            return try jouer(&e, 0, .terminerTour)
        }()
        XCTAssertEqual(e.phase, .terminee)
        XCTAssertEqual(ev.last, .finDeManche(scores: [1, 2]))
        refuse(e, 1, .piocher(source: .defausse), .partieTerminee)
    }
}

final class CochonTests: XCTestCase {
    func testAnnonceEtDerniereOrbiteAQuatre() throws {
        var e = etat(mains: [["AT"], ["2T"], ["3T"], ["4T"]], pioche: pioche20, actif: 1)
        try tourNeutre(&e, cochon: true) // le joueur 1 annonce
        XCTAssertEqual(e.cochonPar, 1)
        XCTAssertEqual(e.toursRestants, 3)
        XCTAssertEqual(e.actif, 2)
        try tourNeutre(&e); XCTAssertEqual(e.actif, 3); XCTAssertEqual(e.toursRestants, 2)
        try tourNeutre(&e); XCTAssertEqual(e.actif, 0); XCTAssertEqual(e.toursRestants, 1)
        // Le joueur 0 joue le dernier tour ; l'annonceur ne rejoue pas.
        let avant = e
        try tourNeutre(&e)
        XCTAssertEqual(e.phase, .terminee)
        XCTAssertEqual(avant.actif, 0)
    }

    func testAnnonceADeux() throws {
        var e = etat(mains: [["AT"], ["2T"]], pioche: pioche20)
        try tourNeutre(&e, cochon: true)
        XCTAssertEqual(e.actif, 1)
        XCTAssertEqual(e.phase, .choixSource)
        try tourNeutre(&e)
        XCTAssertEqual(e.phase, .terminee)
    }

    func testUneSeuleAnnonceParManche() throws {
        var e = etat(mains: [["AT"], ["2T"], ["3T"]], pioche: pioche20)
        try tourNeutre(&e, cochon: true)
        try jouer(&e, 1, .piocher(source: .pioche))
        try jouer(&e, 1, .defausserPiochee)
        try jouer(&e, 1, .passerReflexe)
        refuse(e, 1, .annoncerCochon, .cochonDejaAnnonce)
        XCTAssertEqual(e.vue(pour: 1).coupsPossibles, [.terminerTour])
    }

    func testEvenementDAnnonce() throws {
        var e = etat(mains: [["AT"], ["2T"], ["3T"]], pioche: pioche20)
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        try jouer(&e, 0, .passerReflexe)
        let ev = try jouer(&e, 0, .annoncerCochon)
        XCTAssertEqual(ev, [.cochon(joueur: 0, toursRestants: 2), .tourSuivant(joueur: 1)])
    }

    func testPiocheVidePendantLaDerniereOrbiteFinitAussi() throws {
        var e = etat(mains: [["AT"], ["2T"], ["3T"]], pioche: ["AC", "2C"])
        try tourNeutre(&e, cochon: true)
        try tourNeutre(&e) // dernière carte de la pioche
        XCTAssertEqual(e.phase, .terminee)
    }

    func testToutEstReveleALaFin() throws {
        var e = etat(mains: [["AT", "RC"], ["2T", "RP"]], pioche: pioche20)
        try tourNeutre(&e, cochon: true)
        try tourNeutre(&e)
        let v = e.vue(pour: 1)
        XCTAssertEqual(v.mains[0], [c("AT"), c("RC")])
        XCTAssertEqual(v.scores, [31, 2])
    }
}

final class ScoreTests: XCTestCase {
    func testTotalEtGagnant() {
        let e = etat(mains: [["AT", "RC", "VT"], ["RT", "RP", "2C"], ["10C", "DC"]])
        XCTAssertEqual(Moteur.scores(e), [41, 2, 20])
        XCTAssertEqual(Moteur.gagnants(e), [1])
    }

    func testEgalite() {
        let e = etat(mains: [["5T"], ["2C", "3C"], ["9K"]])
        XCTAssertEqual(Moteur.gagnants(e), [0, 1])
    }

    func testMainVideVautZero() {
        XCTAssertEqual(Moteur.scores(etat(mains: [[], ["AT"]])), [0, 1])
    }

    func testPasDeScoreDansLaVueAvantLaFin() {
        XCTAssertNil(etat(mains: [["AT"], ["2T"]]).vue(pour: 0).scores)
    }
}
