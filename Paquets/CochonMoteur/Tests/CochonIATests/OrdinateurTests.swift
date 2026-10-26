import Foundation
import XCTest
import CochonMoteur
@testable import CochonIA

/// Joue une manche entre ordinateurs. Chaque ordinateur ne reçoit que la vue de son siège.
func manche(_ niveaux: [NiveauIA], graine: UInt64, premier: Int = 0) throws -> EtatPartie {
    let config = ConfigPartie(nombreJoueurs: niveaux.count, premierJoueur: premier)
    var e = try Moteur.nouvellePartie(config: config, graine: graine)
    let ordis = niveaux.enumerated().map { Ordinateur(niveau: $1, graine: graine &+ UInt64($0)) }
    var garde = 0
    while e.phase != .terminee {
        garde += 1
        guard garde < 5_000 else { XCTFail("manche sans fin (graine \(graine))"); break }
        var joue = false
        for j in 0..<niveaux.count {
            let vue = e.vue(pour: j)
            guard let coup = ordis[j].choisir(vue) else { continue }
            XCTAssertTrue(vue.coupsPossibles.contains(coup))
            e = try Moteur.appliquer(Action(joueur: j, coup: coup), a: e).etat
            joue = true
            break
        }
        XCTAssertTrue(joue, "personne ne peut jouer")
        if !joue { break }
    }
    return e
}

final class OrdinateurTests: XCTestCase {
    func testLesDeuxNiveauxFinissentToujoursSansCoupIllegal() throws {
        for graine in UInt64(1)...150 {
            for niveaux in [[NiveauIA.facile, .facile], [.malin, .malin, .malin], [.facile, .malin, .facile, .malin]] {
                let e = try manche(niveaux, graine: graine, premier: Int(graine) % niveaux.count)
                XCTAssertEqual(e.phase, .terminee)
            }
        }
    }

    func testMemeGraineMemesDecisions() throws {
        XCTAssertEqual(try manche([.malin, .facile, .malin], graine: 99), try manche([.malin, .facile, .malin], graine: 99))
    }

    /// Sur 300 manches en tête-à-tête (chacun commence une fois sur deux),
    /// le niveau malin finit nettement plus bas que le facile.
    func testMalinBatFacile() throws {
        var victoiresMalin = 0, victoiresFacile = 0
        var totalMalin = 0, totalFacile = 0
        for graine in UInt64(1)...300 {
            let premier = Int(graine % 2)
            let e = try manche([.malin, .facile], graine: graine, premier: premier)
            let s = Moteur.scores(e)
            totalMalin += s[0]; totalFacile += s[1]
            if s[0] < s[1] { victoiresMalin += 1 } else if s[1] < s[0] { victoiresFacile += 1 }
        }
        print("malin \(victoiresMalin) victoires, moyenne \(Double(totalMalin) / 300) — facile \(victoiresFacile) victoires, moyenne \(Double(totalFacile) / 300)")
        XCTAssertGreaterThan(victoiresMalin, victoiresFacile * 3 / 2)
        XCTAssertLessThan(totalMalin, totalFacile)
    }

    /// L'ordinateur ne lit que la vue : deux parties qui ne diffèrent que
    /// par une carte qu'il n'a jamais vue lui font jouer le même coup.
    func testNeTrichePas() throws {
        var e = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 4)
        for j in 0..<2 { for i in 0..<2 { e = try Moteur.appliquer(Action(joueur: j, coup: .regarder(emplacement: i)), a: e).etat } }
        // Le joueur 0 (ordinateur) ne connaît ni les cartes 2 et 3 de sa main,
        // ni celles de l'adversaire. On les permute entre elles.
        var b = e
        let cachees = [e.mains[0][2], e.mains[0][3], e.mains[1][0], e.mains[1][3]]
        b = remplacerMains(b, [[e.mains[0][0], e.mains[0][1], cachees[3], cachees[2]],
                               [cachees[1], e.mains[1][1], e.mains[1][2], cachees[0]]])
        XCTAssertEqual(e.vue(pour: 0), b.vue(pour: 0))
        for niveau in NiveauIA.allCases {
            let o = Ordinateur(niveau: niveau, graine: 1)
            XCTAssertEqual(o.choisir(e.vue(pour: 0)), o.choisir(b.vue(pour: 0)))
        }
    }

    func testReflexeSeulementSurUneCarteConnue() throws {
        // Dessus de la défausse : 7♥. Il connaît son 7♣ (emplacement 1).
        let vue = vueDeTest(maMain: [nil, c("7T"), c("2T"), nil], defausse: [c("7C")], phase: .reflexe)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(vue), .reflexe(emplacement: 1))
        let sansSept = vueDeTest(maMain: [nil, c("8T"), c("2T"), nil], defausse: [c("7C")], phase: .reflexe)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(sansSept), .passerReflexe)
    }

    func testMalinPrendUnePetiteCarteALaDefausse() throws {
        let vue = vueDeTest(maMain: [c("9T"), c("10P"), c("2T"), c("3T")], defausse: [c("AC")], phase: .choixSource)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(vue), .piocher(source: .defausse))
        let roi = vueDeTest(maMain: [c("9T"), c("10P"), c("2T"), c("3T")], defausse: [c("RC")], phase: .choixSource)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(roi), .piocher(source: .pioche))
    }

    func testMalinRemplaceSaPlusGrosseCarte() throws {
        let vue = vueDeTest(maMain: [c("9T"), c("RK"), c("2T"), c("3T")], defausse: [c("8C")],
                            phase: .cartePiochee(carte: c("4C"), source: .pioche))
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(vue), .remplacer(emplacement: 1))
    }

    func testMalinGardeLaDamePourRegarder() throws {
        let vue = vueDeTest(maMain: [c("2T"), nil, c("3T"), nil], defausse: [c("8C")],
                            phase: .cartePiochee(carte: c("DC"), source: .pioche))
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(vue), .defausserPiochee)
        let dame = vueDeTest(maMain: [c("2T"), nil, c("3T"), nil], defausse: [c("DC")], phase: .pouvoirDame)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(dame), .regarderDame(emplacement: 1))
    }

    func testMalinDonneSaPireCarteAuValet() throws {
        let vue = vueDeTest(maMain: [c("2T"), c("RK"), c("3T"), c("AT")], adversaire: [nil, c("AP"), nil, nil],
                            defausse: [c("VC")], phase: .pouvoirValet)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(vue),
                       .echangerValet(monEmplacement: 1, adversaire: 1, sonEmplacement: 1))
    }

    func testMalinAnnonceCochonAvecUnePetiteMain() throws {
        let petite = vueDeTest(maMain: [c("AT"), c("2T"), c("RP"), c("AP")], defausse: [c("8C")], phase: .finDeTour)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(petite), .annoncerCochon)
        let grosse = vueDeTest(maMain: [c("9T"), nil, c("RC"), nil], defausse: [c("8C")], phase: .finDeTour)
        XCTAssertEqual(Ordinateur(niveau: .malin).choisir(grosse), .terminerTour)
    }

    func testRienAJouerHorsDeSonTour() {
        let vue = vueDeTest(maMain: [nil, nil, nil, nil], defausse: [c("8C")], phase: .choixSource, actif: 1)
        XCTAssertNil(Ordinateur(niveau: .malin).choisir(vue))
    }
}

// MARK: - Outils

func c(_ code: String) -> Carte { Carte(code: code)! }

/// Vue fabriquée pour le joueur 0, contre un adversaire à 4 cartes.
func vueDeTest(maMain: [Carte?], adversaire: [Carte?] = [nil, nil, nil, nil], defausse: [Carte],
               phase: VuePhase, actif: Int = 0) -> VueJoueur {
    VueJoueur(moi: 0, nombreJoueurs: 2, actif: actif, phase: phase,
              mains: [maMain, adversaire], defausse: defausse, cartesDansPioche: 30)
}

func remplacerMains(_ e: EtatPartie, _ mains: [[Carte]]) -> EtatPartie {
    // Passage par JSON : l'état est en lecture seule hors du moteur.
    let enc = JSONEncoder()
    var dict = try! JSONSerialization.jsonObject(with: enc.encode(e)) as! [String: Any]
    dict["mains"] = mains.map { $0.map(\.code) }
    let donnees = try! JSONSerialization.data(withJSONObject: dict)
    return try! JSONDecoder().decode(EtatPartie.self, from: donnees)
}
