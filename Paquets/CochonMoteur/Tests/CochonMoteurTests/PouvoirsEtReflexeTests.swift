import XCTest
@testable import CochonMoteur

final class ValetTests: XCTestCase {
    func enPouvoirValet(mains: [[String]], connues: [[String]]? = nil) throws -> EtatPartie {
        var e = etat(mains: mains, pioche: ["2C", "VC"], connues: connues)
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .pouvoirValet)
        return e
    }

    func testEchangeAveugle() throws {
        var e = try enPouvoirValet(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"], ["9T", "10T", "AP", "2P"]])
        let ev = try jouer(&e, 0, .echangerValet(monEmplacement: 1, adversaire: 2, sonEmplacement: 3))
        XCTAssertEqual(e.mains[0][1], c("2P"))
        XCTAssertEqual(e.mains[2][3], c("2T"))
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(ev, [.echangeValet(joueur: 0, monEmplacement: 1, adversaire: 2, sonEmplacement: 3)])
    }

    /// À l'aveugle : on ne découvre pas la carte reçue. Une carte qu'on
    /// connaissait reste connue à sa nouvelle place (on l'a vue partir).
    func testPersonneNApprendDeFace() throws {
        var e = try enPouvoirValet(
            mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]],
            connues: [["2T"], ["7T"]])
        try jouer(&e, 0, .echangerValet(monEmplacement: 1, adversaire: 1, sonEmplacement: 2))
        XCTAssertNil(e.vue(pour: 0).maMain[1], "la carte reçue reste inconnue")
        XCTAssertEqual(e.vue(pour: 0).mains[1][2], c("2T"), "il sait où est partie la sienne")
        XCTAssertNil(e.vue(pour: 1).maMain[2], "l'adversaire ne découvre pas la carte reçue")
        XCTAssertEqual(e.vue(pour: 1).mains[0][1], c("7T"))
    }

    func testPasDEchangeAvecSoiMemeNiHorsLimites() throws {
        let e = try enPouvoirValet(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]])
        refuse(e, 0, .echangerValet(monEmplacement: 0, adversaire: 0, sonEmplacement: 1), .adversaireInvalide)
        refuse(e, 0, .echangerValet(monEmplacement: 0, adversaire: 2, sonEmplacement: 1), .adversaireInvalide)
        refuse(e, 0, .echangerValet(monEmplacement: 4, adversaire: 1, sonEmplacement: 1), .emplacementInvalide)
        refuse(e, 0, .echangerValet(monEmplacement: 0, adversaire: 1, sonEmplacement: 9), .emplacementInvalide)
    }

    /// Le pouvoir est obligatoire : on ne peut pas passer au réflexe avant.
    func testPouvoirAvantLaSuite() throws {
        let e = try enPouvoirValet(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]])
        refuse(e, 0, .passerReflexe, .coupHorsPhase)
        refuse(e, 0, .terminerTour, .coupHorsPhase)
        refuse(e, 1, .echangerValet(monEmplacement: 0, adversaire: 0, sonEmplacement: 0), .pasTonTour)
    }

    /// Plus aucune carte en face : le pouvoir est perdu, on passe au réflexe.
    func testValetSansCibleEstPerdu() throws {
        var e = etat(mains: [["AT"], []], pioche: ["2C", "VC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        let ev = try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(ev.last, .pouvoirSaute(joueur: 0, carte: c("VC")))
    }
}

final class DameTests: XCTestCase {
    func testRegarderUneDeSesCartes() throws {
        var e = etat(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]], pioche: ["2C", "DC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertNil(e.vue(pour: 0).maMain[3])
        let ev = try jouer(&e, 0, .regarderDame(emplacement: 3))
        XCTAssertEqual(e.vue(pour: 0).maMain[3], c("4T"))
        XCTAssertNil(e.vue(pour: 1).mains[0][3], "les autres ne voient que le geste")
        XCTAssertEqual(ev, [.regardDame(joueur: 0, emplacement: 3)])
        XCTAssertEqual(e.phase, .reflexe)
    }

    func testDameHorsPhaseOuHorsLimites() throws {
        var e = etat(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]], pioche: ["2C", "DC"])
        refuse(e, 0, .regarderDame(emplacement: 0), .coupHorsPhase)
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        refuse(e, 0, .regarderDame(emplacement: 4), .emplacementInvalide)
    }

    func testDameSansCarteEstPerdue() throws {
        var e = etat(mains: [[], ["5T"]], pioche: ["2C", "DC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        let ev = try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(ev.last, .pouvoirSaute(joueur: 0, carte: c("DC")))
    }
}

final class ReflexeTests: XCTestCase {
    /// Défausse : 7♥ après le coup. Main du joueur 0 : un 7♣ en emplacement 2.
    func apresUnCoup(pioche: [String] = ["AC", "2C", "7C"]) throws -> EtatPartie {
        var e = etat(mains: [["AT", "2T", "7T", "4T"], ["5T", "6T", "8T", "9T"]], pioche: pioche)
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .reflexe)
        return e
    }

    func testReflexeReussiReduitLaMain() throws {
        var e = try apresUnCoup()
        let ev = try jouer(&e, 0, .reflexe(emplacement: 2))
        XCTAssertEqual(e.mains[0].map(\.code), ["AT", "2T", "4T"])
        XCTAssertEqual(e.dessusDefausse, c("7T"))
        XCTAssertEqual(e.phase, .finDeTour)
        XCTAssertEqual(ev, [.reflexeReussi(joueur: 0, emplacement: 2, carte: c("7T"))])
    }

    func testReflexeRateDonneUneCarteDePenalite() throws {
        var e = try apresUnCoup()
        let pioche = e.pioche.count
        let ev = try jouer(&e, 0, .reflexe(emplacement: 0))
        XCTAssertEqual(e.mains[0].count, 5, "la carte reste et une pénalité s'ajoute")
        XCTAssertEqual(e.mains[0].last, c("2C"))
        XCTAssertEqual(e.pioche.count, pioche - 1)
        XCTAssertEqual(e.phase, .finDeTour)
        XCTAssertEqual(ev, [.reflexeRate(joueur: 0, emplacement: 0, carteMontree: c("AT"), penalite: true)])
        // La carte montrée est vue de tous ; la pénalité reste cachée, même pour lui.
        XCTAssertEqual(e.vue(pour: 1).mains[0][0], c("AT"))
        XCTAssertNil(e.vue(pour: 0).maMain[4])
    }

    func testReflexeRatePiocheVidePasDePenalite() throws {
        var e = try apresUnCoup(pioche: ["7C"])
        XCTAssertTrue(e.pioche.isEmpty)
        let ev = try jouer(&e, 0, .reflexe(emplacement: 0))
        XCTAssertEqual(e.mains[0].count, 4)
        XCTAssertEqual(ev, [.reflexeRate(joueur: 0, emplacement: 0, carteMontree: c("AT"), penalite: false)])
    }

    func testPasserLeReflexe() throws {
        var e = try apresUnCoup()
        XCTAssertEqual(try jouer(&e, 0, .passerReflexe), [.reflexePasse(joueur: 0)])
        XCTAssertEqual(e.phase, .finDeTour)
    }

    func testUnSeulReflexeParTour() throws {
        var e = try apresUnCoup()
        try jouer(&e, 0, .reflexe(emplacement: 2))
        refuse(e, 0, .reflexe(emplacement: 0), .coupHorsPhase)
    }

    func testReflexeAussiApresUnRemplacement() throws {
        var e = etat(mains: [["AT", "2T", "7T", "4T"], ["5T", "6T", "8T", "9T"]], pioche: ["7K"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .remplacer(emplacement: 1)) // 2♣ part à la défausse
        XCTAssertEqual(e.phase, .reflexe)
        refuse(e, 0, .reflexe(emplacement: 9), .emplacementInvalide)
        try jouer(&e, 0, .reflexe(emplacement: 1)) // le 7♦ posé n'est pas un 2 : raté
        XCTAssertEqual(e.mains[0].count, 4)
    }

    func testReflexeHorsPhaseOuPasSonTour() throws {
        let e = try apresUnCoup()
        refuse(e, 1, .reflexe(emplacement: 0), .pasTonTour)
        refuse(etat(mains: [["7T"], ["7P"]], defausse: ["7C"]), 0, .reflexe(emplacement: 0), .coupHorsPhase)
    }
}
