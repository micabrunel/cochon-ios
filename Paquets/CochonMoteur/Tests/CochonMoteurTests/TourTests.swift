import XCTest
@testable import CochonMoteur

/// Piocher, remplacer, défausser.
final class PiocherTests: XCTestCase {
    let mains = [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]]

    func testPiocherDansLaPioche() throws {
        var e = etat(mains: mains, pioche: ["9T", "10T"])
        let ev = try jouer(&e, 0, .piocher(source: .pioche))
        XCTAssertEqual(e.phase, .cartePiochee(carte: c("10T"), source: .pioche))
        XCTAssertEqual(e.pioche, [c("9T")])
        XCTAssertEqual(ev, [.pioche(joueur: 0, source: .pioche, carteVisible: nil)])
    }

    func testCartePiocheeVueParLuiSeul() throws {
        var e = etat(mains: mains, pioche: ["9T", "10T"])
        try jouer(&e, 0, .piocher(source: .pioche))
        XCTAssertEqual(e.vue(pour: 0).cartePiochee, c("10T"))
        XCTAssertEqual(e.vue(pour: 1).phase, .cartePiochee(carte: nil, source: .pioche))
    }

    func testPrendreLaDefausseEstPublic() throws {
        var e = etat(mains: mains, defausse: ["8K", "9K"])
        let ev = try jouer(&e, 0, .piocher(source: .defausse))
        XCTAssertEqual(e.defausse, [c("8K")])
        XCTAssertEqual(e.vue(pour: 1).phase, .cartePiochee(carte: c("9K"), source: .defausse))
        XCTAssertEqual(ev, [.pioche(joueur: 0, source: .defausse, carteVisible: c("9K"))])
    }

    func testPasTonTour() {
        refuse(etat(mains: mains), 1, .piocher(source: .pioche), .pasTonTour)
        refuse(etat(mains: mains), 3, .piocher(source: .pioche), .joueurInconnu)
    }

    func testOnNePiochePasDeuxFois() throws {
        var e = etat(mains: mains)
        try jouer(&e, 0, .piocher(source: .pioche))
        refuse(e, 0, .piocher(source: .pioche), .coupHorsPhase)
        refuse(e, 0, .piocher(source: .defausse), .coupHorsPhase)
    }

    func testPiocheVideRefusee() {
        refuse(etat(mains: mains, pioche: []), 0, .piocher(source: .pioche), .piocheVide)
    }
}

final class RemplacerTests: XCTestCase {
    let mains = [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]]

    func testRemplacerEnvoieLAncienneALaDefausse() throws {
        var e = etat(mains: mains, pioche: ["9T", "10T"])
        try jouer(&e, 0, .piocher(source: .pioche))
        let ev = try jouer(&e, 0, .remplacer(emplacement: 2))
        XCTAssertEqual(e.mains[0], [c("AT"), c("2T"), c("10T"), c("4T")])
        XCTAssertEqual(e.dessusDefausse, c("3T"))
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(ev, [.remplacement(joueur: 0, emplacement: 2, carteDefaussee: c("3T"))])
    }

    func testLaCartePoseeEstConnueDuJoueurPasDesAutres() throws {
        var e = etat(mains: mains, pioche: ["9T", "10T"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .remplacer(emplacement: 2))
        XCTAssertEqual(e.vue(pour: 0).maMain[2], c("10T"))
        XCTAssertNil(e.vue(pour: 1).mains[0][2])
        // L'ancienne, posée face visible, est connue de tous.
        XCTAssertEqual(e.vue(pour: 1).dessusDefausse, c("3T"))
    }

    func testCartePriseALaDefausseConnueDeTousOuEllePart() throws {
        var e = etat(mains: mains, defausse: ["9K"])
        try jouer(&e, 0, .piocher(source: .defausse))
        try jouer(&e, 0, .remplacer(emplacement: 1))
        XCTAssertEqual(e.vue(pour: 1).mains[0][1], c("9K"), "tout le monde l'a vue partir dans cette main")
    }

    func testCartePriseALaDefausseRemplacementObligatoire() throws {
        var e = etat(mains: mains, defausse: ["9K"])
        try jouer(&e, 0, .piocher(source: .defausse))
        refuse(e, 0, .defausserPiochee, .remplacementObligatoire)
    }

    func testEmplacementInvalide() throws {
        var e = etat(mains: mains)
        try jouer(&e, 0, .piocher(source: .pioche))
        refuse(e, 0, .remplacer(emplacement: 4), .emplacementInvalide)
        refuse(e, 0, .remplacer(emplacement: -1), .emplacementInvalide)
    }

    func testRemplacerSansCarteEnMainRefuse() {
        refuse(etat(mains: mains), 0, .remplacer(emplacement: 0), .coupHorsPhase)
    }

    /// Un Valet qui part à la défausse par remplacement ne donne pas de pouvoir.
    func testPasDePouvoirParRemplacement() throws {
        var e = etat(mains: [["VT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]], pioche: ["DC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .remplacer(emplacement: 0))
        XCTAssertEqual(e.phase, .reflexe)
    }

    /// Un Valet repris à la défausse puis remplacé ne donne pas de pouvoir non plus.
    func testPasDePouvoirDepuisLaDefausse() throws {
        var e = etat(mains: [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]], defausse: ["VC"])
        try jouer(&e, 0, .piocher(source: .defausse))
        try jouer(&e, 0, .remplacer(emplacement: 0))
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(e.dessusDefausse, c("AT"))
    }
}

final class DefausserTests: XCTestCase {
    let mains = [["AT", "2T", "3T", "4T"], ["5T", "6T", "7T", "8T"]]

    func testDefausserUneCarteOrdinaire() throws {
        var e = etat(mains: mains, pioche: ["9C"])
        try jouer(&e, 0, .piocher(source: .pioche))
        let ev = try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.dessusDefausse, c("9C"))
        XCTAssertEqual(e.mains[0].map(\.code), ["AT", "2T", "3T", "4T"])
        XCTAssertEqual(e.phase, .reflexe)
        XCTAssertEqual(ev, [.defausse(joueur: 0, carte: c("9C"))])
    }

    func testValetDefausseDepuisLaPiocheDonneLEchange() throws {
        var e = etat(mains: mains, pioche: ["VC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .pouvoirValet)
    }

    func testDameDefausseeDepuisLaPiocheDonneLeRegard() throws {
        var e = etat(mains: mains, pioche: ["DC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .pouvoirDame)
    }

    func testRoiNAPasDePouvoir() throws {
        var e = etat(mains: mains, pioche: ["RC"])
        try jouer(&e, 0, .piocher(source: .pioche))
        try jouer(&e, 0, .defausserPiochee)
        XCTAssertEqual(e.phase, .reflexe)
    }
}
