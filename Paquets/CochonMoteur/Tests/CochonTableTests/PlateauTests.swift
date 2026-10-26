import CochonIA
import CochonMoteur
@testable import CochonTable
import XCTest

/// Rejoue des manches entières comme l'écran : coup → événements →
/// chorégraphie → mouvements appliqués au plateau. Après chaque coup, le
/// plateau doit être exactement aligné sur la vue du joueur rendue par le
/// moteur : mêmes tas, mêmes mains, et SURTOUT les mêmes faces connues
/// (ni plus, ni moins : l'écran ne peut rien montrer que le joueur n'a
/// pas le droit de voir).
final class PlateauTests: XCTestCase {

    func testLePlateauSuitLeMoteurSurDesManchesEntieres() throws {
        var manches = 0
        for n in 2...4 {
            for graine in UInt64(1)...40 {
                try jouerUneManche(nombreJoueurs: n, graine: graine &* 7919 &+ UInt64(n))
                manches += 1
            }
        }
        XCTAssertEqual(manches, 120)
    }

    func testDistributionPuisPremiereCarte() throws {
        let arbitre = try Arbitre(config: ConfigPartie(nombreJoueurs: 3), niveau: .malin, graine: 42)
        var plateau = Plateau(nombreJoueurs: 3)
        let etapes = Choregraphie.distribution(nombreJoueurs: 3, premiere: arbitre.vue.defausse[0], rythme: Rythme())
        for e in etapes { plateau.appliquer(e.mouvements) }
        verifier(plateau, arbitre.vue, "après distribution")
        XCTAssertEqual(plateau.mains.map(\.count), [4, 4, 4])
    }

    func testUneCarteDOrdinateurPiocheeResteCachee() throws {
        var plateau = Plateau(nombreJoueurs: 2)
        plateau.appliquer(.prendre(joueur: 1, source: .pioche, face: nil))
        plateau.appliquer(.montrerTenue(true))
        let tenue = plateau.jetonsAffiches().first { if case .tenue = $0.lieu { return true } else { return false } }
        XCTAssertNotNil(tenue)
        XCTAssertNil(tenue?.face)
        XCTAssertEqual(tenue?.montree, false, "une face inconnue ne peut pas être montrée")
    }

    func testEchangeValetCroiseLesJetons() {
        var plateau = Plateau(nombreJoueurs: 2)
        for _ in 0..<4 { plateau.appliquer([.distribuer(joueur: 0), .distribuer(joueur: 1)]) }
        let a = plateau.mains[0][1], b = plateau.mains[1][3]
        plateau.appliquer(.echanger(joueur: 0, emplacement: 1, adversaire: 1, sonEmplacement: 3))
        XCTAssertEqual(plateau.mains[0][1], b)
        XCTAssertEqual(plateau.mains[1][3], a)
    }

    func testEcarterResserreLaMain() {
        var plateau = Plateau(nombreJoueurs: 2)
        for _ in 0..<4 { plateau.appliquer([.distribuer(joueur: 0), .distribuer(joueur: 1)]) }
        let apres = plateau.mains[0][2]
        plateau.appliquer(.ecarter(joueur: 0, emplacement: 1, carte: Carte(.sept, .coeur)))
        XCTAssertEqual(plateau.mains[0].count, 3)
        XCTAssertEqual(plateau.mains[0][1], apres)
        XCTAssertEqual(plateau.defausse.last.flatMap { plateau.faces[$0] }, Carte(.sept, .coeur))
    }

    func testSeulsLesDessusDesTasSontDessines() {
        let plateau = Plateau(nombreJoueurs: 2)
        XCTAssertEqual(plateau.jetonsAffiches().count, 3)
        XCTAssertEqual(Set(plateau.jetonsAffiches().map(\.id)), [49, 50, 51])
    }

    func testModeTestMontreLesCartesConnuesSeulement() {
        var plateau = Plateau(nombreJoueurs: 2)
        for _ in 0..<4 { plateau.appliquer([.distribuer(joueur: 0), .distribuer(joueur: 1)]) }
        plateau.appliquer(.montrer(joueur: 0, emplacement: 0, face: Carte(.un, .pique), false))
        let montrees = plateau.jetonsAffiches(toutMontrer: true).filter(\.montree)
        XCTAssertEqual(montrees.map(\.face), [Carte(.un, .pique)])
    }

    // MARK: - Outils

    private func jouerUneManche(nombreJoueurs n: Int, graine: UInt64) throws {
        var arbitre = try Arbitre(config: ConfigPartie(nombreJoueurs: n, premierJoueur: Int(graine % UInt64(n))),
                                  niveau: graine % 2 == 0 ? .malin : .facile, graine: graine)
        let rythme = Rythme()
        // Le joueur humain est joué par un ordinateur qui ne lit que sa vue.
        let humain = Ordinateur(niveau: .malin, graine: graine &+ 99)
        var plateau = Plateau(nombreJoueurs: n)
        for e in Choregraphie.distribution(nombreJoueurs: n, premiere: arbitre.vue.defausse[0], rythme: rythme) {
            plateau.appliquer(e.mouvements)
        }
        verifier(plateau, arbitre.vue, "distribution, graine \(graine)")

        var garde = 0
        while arbitre.vue.phase != .terminee {
            garde += 1
            guard garde < 5_000 else { return XCTFail("manche sans fin (graine \(graine))") }
            let evenements: [Evenement]
            // Une manche sur trois, les ordinateurs regardent leurs cartes
            // avant le joueur (ordre de l'app) ; sinon après.
            let ordisDAbord = graine % 3 == 0 && arbitre.vue.phase == .ouverture
            if ordisDAbord, let action = arbitre.prochainCoupOrdinateur() {
                evenements = try arbitre.jouerOrdinateur(action)
            } else if let coup = humain.choisir(arbitre.vue) {
                evenements = try arbitre.jouer(coup)
            } else if let action = arbitre.prochainCoupOrdinateur() {
                evenements = try arbitre.jouerOrdinateur(action)
            } else {
                return XCTFail("personne ne peut jouer (graine \(graine))")
            }
            let vue = arbitre.vue
            for etape in Choregraphie.etapes(pour: evenements, moi: arbitre.moi, vueApres: vue, rythme: rythme) {
                plateau.appliquer(etape.mouvements)
            }
            verifier(plateau, vue, "coup \(vue.numeroCoup), graine \(graine)")
            if !plateau.souleves.isEmpty || !plateau.inclines.isEmpty {
                return XCTFail("carte restée soulevée ou inclinée (graine \(graine))")
            }
        }
        let fin = plateau.jetonsAffiches(profondeurVisible: 0)
        XCTAssertTrue(fin.allSatisfy(\.montree), "tout est révélé en fin de manche")
    }

    private func verifier(_ p: Plateau, _ vue: VueJoueur, _ ou: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.pioche.count, vue.cartesDansPioche, "pioche — \(ou)", file: file, line: line)
        XCTAssertEqual(p.defausse.map { p.faces[$0] }, vue.defausse.map { Optional($0) }, "défausse — \(ou)", file: file, line: line)
        XCTAssertEqual(p.mains.map(\.count), vue.mains.map(\.count), "mains — \(ou)", file: file, line: line)
        for (j, main) in p.mains.enumerated() where j < vue.mains.count {
            for (i, id) in main.enumerated() where i < vue.mains[j].count {
                XCTAssertEqual(p.faces[id], vue.mains[j][i], "face \(j)/\(i) — \(ou)", file: file, line: line)
            }
        }
        if case .cartePiochee(let c, _) = vue.phase {
            XCTAssertEqual(p.tenue?.joueur, vue.actif, "tenue — \(ou)", file: file, line: line)
            XCTAssertEqual(p.tenue.flatMap { p.faces[$0.jeton] }, c, "face tenue — \(ou)", file: file, line: line)
        } else {
            XCTAssertNil(p.tenue, "rien en main — \(ou)", file: file, line: line)
        }
        var tous = p.pioche + p.defausse + p.mains.flatMap { $0 }
        if let t = p.tenue { tous.append(t.jeton) }
        XCTAssertEqual(tous.sorted(), Array(0..<52), "52 jetons, chacun une fois — \(ou)", file: file, line: line)
    }
}
