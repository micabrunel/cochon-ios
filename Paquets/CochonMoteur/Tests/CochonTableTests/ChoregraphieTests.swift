import CochonMoteur
@testable import CochonTable
import XCTest

final class ChoregraphieTests: XCTestCase {
    let roiPique = Carte(.roi, .pique)

    func testDistributionQuatreCartesParSeconde() {
        let e = Choregraphie.distribution(nombreJoueurs: 4, premiere: roiPique, rythme: Rythme())
        XCTAssertEqual(e.count, 17, "16 cartes une par une, puis la défausse")
        let distribution = e.dropLast()
        XCTAssertTrue(distribution.allSatisfy { $0.style == .distribution })
        XCTAssertEqual(distribution.map(\.attente).reduce(0, +), 4.0, accuracy: 0.001, "16 cartes en 4 s")
        // Une carte à chacun, à tour de rôle, comme le moteur.
        XCTAssertEqual(distribution.prefix(4).map(\.mouvements), [0, 1, 2, 3].map { [.distribuer(joueur: $0)] })
        XCTAssertEqual(e.last?.mouvements, [.retournerSurDefausse(roiPique)])
    }

    func testVitesseRapideEtTranquille() {
        let rapide = Choregraphie.distribution(nombreJoueurs: 2, premiere: roiPique, rythme: Rythme(vitesse: .rapide))
        let lente = Choregraphie.distribution(nombreJoueurs: 2, premiere: roiPique, rythme: Rythme(vitesse: .tranquille))
        XCTAssertLessThan(rapide[0].attente, 0.25)
        XCTAssertGreaterThan(lente[0].attente, 0.25)
    }

    func testMaCartePiocheeVolepuisSeRetourne() {
        let vue = vueTenue(moi: 0, actif: 0, carte: roiPique)
        let e = Choregraphie.etapes(pour: [.pioche(joueur: 0, source: .pioche, carteVisible: nil)],
                                    moi: 0, vueApres: vue, rythme: Rythme())
        XCTAssertEqual(e.map(\.style), [.vol, .retournement])
        XCTAssertEqual(e[0].mouvements, [.prendre(joueur: 0, source: .pioche, face: roiPique)])
        XCTAssertEqual(e[1].mouvements, [.montrerTenue(true)])
    }

    func testLaCartePiocheeParUnOrdiNestNiLueNiRetournee() {
        let vue = vueTenue(moi: 0, actif: 1, carte: nil)
        let e = Choregraphie.etapes(pour: [.pioche(joueur: 1, source: .pioche, carteVisible: nil)],
                                    moi: 0, vueApres: vue, rythme: Rythme())
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0].mouvements, [.prendre(joueur: 1, source: .pioche, face: nil)])
    }

    func testValetDeuxCartesQuiSeCroisent() {
        let vue = vueSimple(phase: .reflexe)
        let e = Choregraphie.etapes(pour: [.echangeValet(joueur: 0, monEmplacement: 2, adversaire: 1, sonEmplacement: 0)],
                                    moi: 0, vueApres: vue, rythme: Rythme())
        XCTAssertEqual(e.map(\.style), [.soulevement, .croisement, .soulevement])
        XCTAssertEqual(e[0].mouvements.count, 2, "les deux cartes se soulèvent ensemble")
        XCTAssertEqual(e[1].mouvements, [.echanger(joueur: 0, emplacement: 2, adversaire: 1, sonEmplacement: 0)])
    }

    func testDameMaCarteSeSouleveSeRetourneEtSeRecache() {
        var mains: [[Carte?]] = [[nil, nil, nil, nil], [nil, nil, nil, nil]]
        mains[0][3] = Carte(.cinq, .trefle)
        let vue = vueSimple(phase: .reflexe, mains: mains)
        let e = Choregraphie.etapes(pour: [.regardDame(joueur: 0, emplacement: 3)], moi: 0, vueApres: vue, rythme: Rythme())
        XCTAssertEqual(e.map(\.style), [.soulevement, .retournement, .retournement, .soulevement])
        XCTAssertEqual(e[1].mouvements, [.montrer(joueur: 0, emplacement: 3, face: Carte(.cinq, .trefle), true)])
        XCTAssertGreaterThanOrEqual(e[1].attente, 1.2, "le temps de la lire")
    }

    func testDameDUnOrdiCoupDOeilSansFace() {
        let e = Choregraphie.etapes(pour: [.regardDame(joueur: 1, emplacement: 0)], moi: 0,
                                    vueApres: vueSimple(phase: .reflexe), rythme: Rythme())
        let tout = e.flatMap(\.mouvements)
        XCTAssertTrue(tout.contains(.incliner(joueur: 1, emplacement: 0, true)))
        XCTAssertFalse(tout.contains { if case .montrer = $0 { return true } else { return false } })
    }

    func testReflexeRatePlusUnFlottantEtHaptiqueDErreur() {
        let e = Choregraphie.etapes(pour: [.reflexeRate(joueur: 0, emplacement: 1, carteMontree: roiPique, penalite: true)],
                                    moi: 0, vueApres: vueSimple(phase: .finDeTour), rythme: Rythme())
        XCTAssertEqual(e.first?.haptique, .erreur)
        XCTAssertEqual(e.last?.mouvements, [.penalite(joueur: 0)])
        XCTAssertEqual(e.last?.annonce, .plusUn(joueur: 0))
    }

    func testReflexeReussi() {
        let e = Choregraphie.etapes(pour: [.reflexeReussi(joueur: 0, emplacement: 1, carte: roiPique)],
                                    moi: 0, vueApres: vueSimple(phase: .finDeTour), rythme: Rythme())
        XCTAssertEqual(e.last?.haptique, .succes)
        XCTAssertEqual(e.last?.annonce, .reflexeReussi(joueur: 0))
    }

    func testCochonGrandeAnnonce() {
        let e = Choregraphie.etapes(pour: [.cochon(joueur: 2, toursRestants: 2), .tourSuivant(joueur: 3)],
                                    moi: 0, vueApres: vueSimple(phase: .choixSource), rythme: Rythme())
        XCTAssertEqual(e.first?.annonce, .cochon(joueur: 2, toursRestants: 2))
        XCTAssertEqual(e.first?.haptique, .fort)
        XCTAssertGreaterThanOrEqual(e.first?.attente ?? 0, 1.5)
    }

    func testTourDuJoueurAnnonceEtHaptique() {
        let e = Choregraphie.etapes(pour: [.tourSuivant(joueur: 0)], moi: 0,
                                    vueApres: vueSimple(phase: .choixSource), rythme: Rythme())
        XCTAssertEqual(e.first?.annonce, .aToi)
        XCTAssertEqual(e.first?.haptique, .selection)
    }

    func testPouvoirDuValetAnnonceQuandLeMoteurLeDonne() {
        let valet = Carte(.valet, .trefle)
        let e = Choregraphie.etapes(pour: [.defausse(joueur: 1, carte: valet)], moi: 0,
                                    vueApres: vueSimple(phase: .pouvoirValet, actif: 1), rythme: Rythme())
        XCTAssertEqual(e.first?.annonce, .valet(joueur: 1))
    }

    func testLesOrdisRegardentLeursCartesEnMemeTemps() {
        let vue = vueSimple(phase: .ouverture)
        let suites = [(1, 0), (1, 2), (2, 1)].map { j, emp in
            Choregraphie.etapes(pour: [.regardOuverture(joueur: j, emplacement: emp)], moi: 0, vueApres: vue, rythme: Rythme())
        }
        let ensemble = Choregraphie.simultanees(suites)
        XCTAssertEqual(ensemble.count, 2, "toutes les cartes se soulèvent ensemble, puis se reposent ensemble")
        XCTAssertEqual(ensemble[0].mouvements.count, 6)
        XCTAssertTrue(ensemble[0].mouvements.contains(.incliner(joueur: 2, emplacement: 1, true)))
        XCTAssertEqual(ensemble[0].attente, suites[0][0].attente)
        XCTAssertEqual(Choregraphie.simultanees([]), [])
    }

    func testReduireLesAnimationsGardeLesPauses() {
        let normal = Rythme()
        let reduit = Rythme(reduire: true)
        for s in [StyleAnimation.vol, .retournement, .soulevement, .croisement, .distribution] {
            XCTAssertEqual(reduit.style(s), .immediat, "\(s) : pas de mouvement")
            XCTAssertEqual(reduit.dureeAnimation(s), 0.2, accuracy: 0.001, "\(s) : fondu court")
        }
        XCTAssertEqual(normal.style(.vol), .vol)
        // Les attentes ne dépendent pas du réglage : le tour des ordis reste lisible.
        let a = Choregraphie.distribution(nombreJoueurs: 2, premiere: roiPique, rythme: normal).map(\.attente)
        let b = Choregraphie.distribution(nombreJoueurs: 2, premiere: roiPique, rythme: reduit).map(\.attente)
        XCTAssertEqual(a, b)
    }

    func testAnimationsCourtesSousLesTroisDixiemes() {
        let r = Rythme()
        XCTAssertLessThanOrEqual(r.dureeAnimation(.soulevement), 0.2)
        XCTAssertLessThanOrEqual(r.dureeAnimation(.retournement), 0.4)
        XCTAssertLessThanOrEqual(r.dureeAnimation(.vol), 0.45)
    }

    func testPausesDesOrdis() {
        let r = Rythme()
        XCTAssertEqual(r.pauseAvant(.passerReflexe), 0)
        XCTAssertEqual(r.pauseAvant(.terminerTour), 0)
        XCTAssertGreaterThan(r.pauseAvant(.piocher(source: .pioche)), 0.4)
        XCTAssertGreaterThan(r.pauseAvant(.remplacer(emplacement: 0)), 0.4)
    }

    // MARK: - Outils

    func vueSimple(phase: VuePhase, actif: Int = 0, mains: [[Carte?]]? = nil) -> VueJoueur {
        let m = mains ?? [[nil, nil, nil, nil], [nil, nil, nil, nil]]
        return VueJoueur(moi: 0, nombreJoueurs: m.count, actif: actif, phase: phase, mains: m,
                         defausse: [Carte(.deux, .pique)], cartesDansPioche: 30)
    }

    func vueTenue(moi: Int, actif: Int, carte: Carte?) -> VueJoueur {
        VueJoueur(moi: moi, nombreJoueurs: 2, actif: actif, phase: .cartePiochee(carte: carte, source: .pioche),
                  mains: [[nil, nil, nil, nil], [nil, nil, nil, nil]], defausse: [Carte(.deux, .pique)], cartesDansPioche: 30)
    }
}
