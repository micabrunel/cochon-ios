import XCTest
@testable import CochonMoteur

final class ValeursDesCartesTests: XCTestCase {
    func testAsVautUn() {
        for coul in Couleur.allCases { XCTAssertEqual(Carte(.un, coul).valeur, 1) }
    }

    func testDeuxADixValentLeurChiffre() {
        for r in Rang.allCases where (2...10).contains(r.rawValue) {
            XCTAssertEqual(Carte(r, .coeur).valeur, r.rawValue)
        }
    }

    func testValetEtDameValentDix() {
        for coul in Couleur.allCases {
            XCTAssertEqual(Carte(.valet, coul).valeur, 10)
            XCTAssertEqual(Carte(.dame, coul).valeur, 10)
        }
    }

    func testRoisNoirsZeroRoisRougesTrente() {
        XCTAssertEqual(c("RT").valeur, 0)
        XCTAssertEqual(c("RP").valeur, 0)
        XCTAssertEqual(c("RC").valeur, 30)
        XCTAssertEqual(c("RK").valeur, 30)
    }

    func testPaquetDeCinquanteDeuxCartesDifferentes() {
        XCTAssertEqual(Carte.paquetComplet.count, 52)
        XCTAssertEqual(Set(Carte.paquetComplet).count, 52)
        // 4 × (1+…+10) + 4 × (10+10) + 0 + 0 + 30 + 30
        XCTAssertEqual(Moteur.total(Carte.paquetComplet), 360)
    }

    func testCodesAllerRetour() {
        for carte in Carte.paquetComplet {
            XCTAssertEqual(Carte(code: carte.code), carte)
            XCTAssertEqual(Carte(numero: carte.numero), carte)
        }
        XCTAssertEqual(c("10C"), Carte(.dix, .coeur))
        XCTAssertNil(Carte(code: "11C"))
        XCTAssertNil(Carte(code: "AX"))
    }

    func testEnsembleDeCartes() {
        var e = EnsembleCartes()
        e.insert(c("AT")); e.insert(c("RK")); e.insert(c("AT"))
        XCTAssertEqual(e.count, 2)
        XCTAssertTrue(e.contains(c("RK")))
        e.remove(c("RK"))
        XCTAssertFalse(e.contains(c("RK")))
        XCTAssertEqual(Array(EnsembleCartes(Carte.paquetComplet)), Carte.paquetComplet)
    }
}

final class HasardReproductibleTests: XCTestCase {
    /// Valeurs de référence publiées de SplitMix64 pour la graine 0 : le
    /// générateur donne la même suite partout (iPhone, Mac, serveur Linux).
    func testSplitMix64ValeursDeReference() {
        var g = GenerateurDeterministe(graine: 0)
        XCTAssertEqual(g.next(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(g.next(), 0x6E78_9E6A_A1B9_65F4)
        XCTAssertEqual(g.next(), 0x06C4_5D18_8009_454F)
    }

    func testMemeGraineMemeDonne() throws {
        let a = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 4), graine: 42)
        let b = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 4), graine: 42)
        XCTAssertEqual(a, b)
    }

    func testGrainesDifferentesDonnesDifferentes() throws {
        let a = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 4), graine: 1)
        let b = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 4), graine: 2)
        XCTAssertNotEqual(a.mains, b.mains)
    }

    /// Empreinte figée de la donne de la graine 2026 : si elle change, les
    /// parties enregistrées (et le serveur) ne se rejoueraient plus pareil.
    func testDonneFigee() throws {
        let e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 2026)
        var g = GenerateurDeterministe(graine: 2026)
        let attendu = g.melanger(Carte.paquetComplet)
        // Distribution une par une depuis le dessus (fin du tableau).
        XCTAssertEqual(e.mains[0], [attendu[51], attendu[49], attendu[47], attendu[45]])
        XCTAssertEqual(e.mains[1], [attendu[50], attendu[48], attendu[46], attendu[44]])
        XCTAssertEqual(e.defausse, [attendu[43]])
        XCTAssertEqual(e.pioche, Array(attendu[0..<43]))
        // Valeurs relevées le 26/10/2026 (Swift 6.1, Linux) : à ne jamais changer.
        XCTAssertEqual(e.mains.map { $0.map(\.code) }, [["7P", "9C", "3K", "2C"], ["3P", "3C", "8K", "10K"]])
        XCTAssertEqual(e.defausse.map(\.code), ["7T"])
        XCTAssertEqual(e.pioche.suffix(3).map(\.code), ["8P", "DT", "2K"])
    }

    func testMelangeEstUnePermutation() {
        var g = GenerateurDeterministe(graine: 7)
        let m = g.melanger(Carte.paquetComplet)
        XCTAssertEqual(Set(m), Set(Carte.paquetComplet))
        XCTAssertNotEqual(m, Carte.paquetComplet)
    }

    func testUniformeResteDansLesBornes() {
        var g = GenerateurDeterministe(graine: 3)
        var vus = Set<Int>()
        for _ in 0..<1000 {
            let x = g.uniforme(5)
            XCTAssertTrue((0..<5).contains(x))
            vus.insert(x)
        }
        XCTAssertEqual(vus, [0, 1, 2, 3, 4])
    }
}
