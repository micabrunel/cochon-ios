import CochonMoteur
@testable import CochonTable
import Foundation
import XCTest

final class PlacesEtDispositionTests: XCTestCase {

    func testPlacesSelonLeNombreDeJoueurs() {
        XCTAssertEqual((0..<2).map { Place.de($0, moi: 0, nombreJoueurs: 2) }, [.bas, .haut])
        XCTAssertEqual((0..<3).map { Place.de($0, moi: 0, nombreJoueurs: 3) }, [.bas, .gauche, .droite])
        XCTAssertEqual((0..<4).map { Place.de($0, moi: 0, nombreJoueurs: 4) }, [.bas, .gauche, .haut, .droite])
        // En ligne, je ne serai pas toujours le joueur 0 : je reste en bas.
        XCTAssertEqual((0..<4).map { Place.de($0, moi: 2, nombreJoueurs: 4) }, [.haut, .droite, .bas, .gauche])
    }

    /// Zone sûre de l'écran de la maquette (390 × 763) : on retrouve ses cotes.
    func testMaMainReprendLaMaquette() {
        let d = Disposition(taille: CGSize(width: 390, height: 763), moi: 0, nombreJoueurs: 4)
        let xs = (0..<4).map { d.pose(.main(joueur: 0, emplacement: $0), tailleMain: 4).centre.x }
        for (x, attendu) in zip(xs, [44.0, 105.0, 166.0, 227.0]) { XCTAssertEqual(Double(x), attendu, accuracy: 0.5) }
        let p = d.pose(.main(joueur: 0, emplacement: 0), tailleMain: 4)
        XCTAssertEqual(p.taille, CGSize(width: 56, height: 82))
        XCTAssertEqual(p.rotation, -6, accuracy: 0.01)
        XCTAssertEqual(Double(d.pioche.y), 362 - 47, accuracy: 0.01)
    }

    func testLEventailNePasseJamaisSousLeBoutonCochon() {
        let d = Disposition(taille: CGSize(width: 390, height: 763), moi: 0, nombreJoueurs: 2)
        let bordBouton = d.boutonCochon.x - d.diametreCochon / 2
        for n in 1...9 {
            let derniere = d.pose(.main(joueur: 0, emplacement: n - 1), tailleMain: n)
            XCTAssertLessThan(derniere.centre.x + derniere.taille.width / 2, bordBouton + 1, "\(n) cartes")
            let premiere = d.pose(.main(joueur: 0, emplacement: 0), tailleMain: n)
            XCTAssertGreaterThan(premiere.centre.x - premiere.taille.width / 2, 0, "\(n) cartes")
        }
    }

    func testToutTientSurUnIphoneSE() {
        let taille = CGSize(width: 375, height: 647)
        let d = Disposition(taille: taille, moi: 0, nombreJoueurs: 4)
        var poses: [Pose] = [d.carteTenue]
        for j in 0..<4 { for i in 0..<6 { poses.append(d.pose(.main(joueur: j, emplacement: i), tailleMain: 6)) } }
        poses.append(d.pose(.pioche(profondeur: 2)))
        poses.append(d.pose(.defausse(profondeur: 1, rang: 3)))
        for p in poses {
            XCTAssertGreaterThanOrEqual(p.centre.x - p.taille.width / 2, -1)
            XCTAssertLessThanOrEqual(p.centre.x + p.taille.width / 2, taille.width + 1)
            XCTAssertGreaterThanOrEqual(p.centre.y - p.taille.height / 2, -1)
            XCTAssertLessThanOrEqual(p.centre.y + p.taille.height / 2, taille.height + 1)
        }
    }

    func testLaCarteTenueParUnOrdiVientDeSonCote() {
        let d = Disposition(taille: CGSize(width: 390, height: 763), moi: 0, nombreJoueurs: 4)
        XCTAssertLessThan(d.pose(.tenue(joueur: 1)).centre.x, d.centreTable.x)
        XCTAssertLessThan(d.pose(.tenue(joueur: 2)).centre.y, d.centreTable.y)
        XCTAssertGreaterThan(d.pose(.tenue(joueur: 3)).centre.x, d.centreTable.x)
    }
}

final class IntentionsTests: XCTestCase {

    func vue(_ phase: VuePhase, actif: Int = 0, cochonPar: Int? = nil, pioche: Int = 20) -> VueJoueur {
        VueJoueur(moi: 0, nombreJoueurs: 3, actif: actif, phase: phase,
                  mains: Array(repeating: [nil, nil, nil, nil], count: 3),
                  defausse: [Carte(.sept, .coeur)], cartesDansPioche: pioche, cochonPar: cochonPar)
    }

    func testFinDuTourEnchaineLesCoupsDeService() {
        XCTAssertEqual(Intentions.reponse(.finDuTour, vue: vue(.reflexe)), .jouer([.passerReflexe, .terminerTour]))
        XCTAssertEqual(Intentions.reponse(.finDuTour, vue: vue(.finDeTour)), .jouer([.terminerTour]))
        XCTAssertEqual(Intentions.reponse(.finDuTour, vue: vue(.choixSource)), .rien)
    }

    func testCochonSeulementEnFinDeTourEtUneFois() {
        XCTAssertEqual(Intentions.reponse(.cochon, vue: vue(.reflexe)), .jouer([.passerReflexe, .annoncerCochon]))
        XCTAssertEqual(Intentions.reponse(.cochon, vue: vue(.finDeTour)), .jouer([.annoncerCochon]))
        XCTAssertEqual(Intentions.reponse(.cochon, vue: vue(.finDeTour, cochonPar: 2)), .rien)
        XCTAssertEqual(Intentions.reponse(.cochon, vue: vue(.choixSource)), .rien)
        XCTAssertEqual(Intentions.reponse(.cochon, vue: vue(.finDeTour, actif: 1)), .rien, "pas mon tour")
        XCTAssertFalse(Intentions.commandes(vue(.finDeTour, cochonPar: 1)).cochonActif)
        XCTAssertTrue(Intentions.commandes(vue(.reflexe)).cochonActif)
    }

    func testToucherLaDefausseEnTenantUneCarteDeLaPiocheLaDefausse() {
        let tenue = vue(.cartePiochee(carte: Carte(.roi, .pique), source: .pioche))
        XCTAssertEqual(Intentions.reponse(.defausse, vue: tenue), .jouer([.defausserPiochee]))
        XCTAssertEqual(Intentions.reponse(.defausse, vue: vue(.choixSource)), .jouer([.piocher(source: .defausse)]))
        let prise = vue(.cartePiochee(carte: Carte(.sept, .coeur), source: .defausse))
        XCTAssertEqual(Intentions.reponse(.defausse, vue: prise), .rien, "carte prise à la défausse : remplacement obligatoire")
        XCTAssertEqual(Intentions.reponse(.boutonDefausser, vue: prise), .rien)
        XCTAssertFalse(Intentions.commandes(prise).defausserVisible)
        XCTAssertTrue(Intentions.commandes(prise).remplacerVisible)
    }

    func testValetEnDeuxTemps() {
        let v = vue(.pouvoirValet)
        XCTAssertEqual(Intentions.reponse(.maCarte(2), vue: v), .choisirValet(2))
        XCTAssertEqual(Intentions.reponse(.carteAdverse(joueur: 1, emplacement: 0), vue: v), .rien, "ma carte d'abord")
        XCTAssertEqual(Intentions.reponse(.carteAdverse(joueur: 1, emplacement: 0), vue: v, valetMien: 2),
                       .jouer([.echangerValet(monEmplacement: 2, adversaire: 1, sonEmplacement: 0)]))
        XCTAssertTrue(Intentions.commandes(v, valetMien: 2).adversesTouchables)
        XCTAssertFalse(Intentions.commandes(v).adversesTouchables)
    }

    func testPiocheEtIndice() {
        XCTAssertEqual(Intentions.reponse(.pioche, vue: vue(.choixSource)), .jouer([.piocher(source: .pioche)]))
        XCTAssertTrue(Intentions.commandes(vue(.choixSource)).piochePossible)
        XCTAssertFalse(Intentions.commandes(vue(.choixSource, actif: 1)).piochePossible, "pas d'indice hors de mon tour")
        XCTAssertFalse(Intentions.commandes(vue(.choixSource, pioche: 0)).piochePossible)
    }

    func testMaCarteSelonLaPhase() {
        XCTAssertEqual(Intentions.reponse(.maCarte(1), vue: vue(.cartePiochee(carte: Carte(.un, .trefle), source: .pioche))),
                       .jouer([.remplacer(emplacement: 1)]))
        XCTAssertEqual(Intentions.reponse(.maCarte(1), vue: vue(.pouvoirDame)), .jouer([.regarderDame(emplacement: 1)]))
        XCTAssertEqual(Intentions.reponse(.maCarte(1), vue: vue(.reflexe)), .jouer([.reflexe(emplacement: 1)]))
        XCTAssertEqual(Intentions.reponse(.maCarte(1), vue: vue(.choixSource)), .rien)
        XCTAssertEqual(Intentions.reponse(.boutonRemplacer, vue: vue(.cartePiochee(carte: Carte(.un, .trefle), source: .pioche))),
                       .attendreRemplacement)
    }
}

final class TextesTests: XCTestCase {

    func testLegendeDeLaMaquette() {
        let v = VueJoueur(moi: 0, nombreJoueurs: 4, actif: 0, phase: .cartePiochee(carte: Carte(.roi, .pique), source: .pioche),
                          mains: Array(repeating: [nil, nil, nil, nil], count: 4), defausse: [], cartesDansPioche: 20)
        XCTAssertEqual(Textes.legendeTenue(v), "Tu as pioché un Roi ♠ : 0 point !")
    }

    func testLegendesDesPouvoirsEtDeLaDefausse() {
        func v(_ c: Carte, _ s: Source) -> VueJoueur {
            VueJoueur(moi: 0, nombreJoueurs: 2, actif: 0, phase: .cartePiochee(carte: c, source: s),
                      mains: [[nil], [nil]], defausse: [], cartesDansPioche: 20)
        }
        XCTAssertEqual(Textes.legendeTenue(v(Carte(.dame, .coeur), .pioche)), "Une Dame ♥ ! Défausse-la pour regarder une de tes cartes.")
        XCTAssertEqual(Textes.legendeTenue(v(Carte(.valet, .trefle), .pioche)), "Un Valet ♣ ! Défausse-le pour échanger une carte.")
        XCTAssertEqual(Textes.legendeTenue(v(Carte(.roi, .coeur), .pioche)), "Tu as pioché un Roi ♥ : 30 points !")
        XCTAssertEqual(Textes.legendeTenue(v(Carte(.sept, .carreau), .defausse)), "Tu as pris un 7 ♦ : choisis la carte à remplacer.")
    }

    func testBanniere() {
        let v = VueJoueur(moi: 0, nombreJoueurs: 4, actif: 2, phase: .choixSource,
                          mains: Array(repeating: [nil], count: 4), defausse: [], cartesDansPioche: 20)
        XCTAssertEqual(Textes.banniere(v, tour: 6), Textes.Banniere(titre: "ORDI 2 joue", detail: "Tour 6", aMoi: false))
        let fin = VueJoueur(moi: 0, nombreJoueurs: 4, actif: 0, phase: .choixSource,
                            mains: Array(repeating: [nil], count: 4), defausse: [], cartesDansPioche: 20, cochonPar: 3)
        XCTAssertEqual(Textes.banniere(fin, tour: 9), Textes.Banniere(titre: "À toi !", detail: "Dernier tour", aMoi: true))
    }

    func testConsigneDuReflexeAccordeLeRang() {
        let v = VueJoueur(moi: 0, nombreJoueurs: 2, actif: 0, phase: .reflexe,
                          mains: [[nil], [nil]], defausse: [Carte(.dame, .pique)], cartesDansPioche: 20)
        XCTAssertEqual(Textes.consigne(v), "Une Dame dans ta main ? Touche-la. Sinon, fin du tour.")
    }

    func testResultatsClassesEtEgalite() {
        let v = VueJoueur(moi: 0, nombreJoueurs: 3, actif: 0, phase: .terminee,
                          mains: Array(repeating: [], count: 3), defausse: [], cartesDansPioche: 0,
                          cochonPar: 2, scores: [12, 4, 4])
        let r = Textes.resultats(v)
        XCTAssertEqual(r.map(\.joueur), [1, 2, 0])
        XCTAssertEqual(r.map(\.gagnant), [true, true, false])
        XCTAssertEqual(r.first { $0.joueur == 2 }?.aAnnonce, true)
        XCTAssertEqual(Textes.titreResultats(v), "Égalité !")
        let gagne = VueJoueur(moi: 0, nombreJoueurs: 2, actif: 0, phase: .terminee, mains: [[], []],
                              defausse: [], cartesDansPioche: 0, scores: [3, 9])
        XCTAssertEqual(Textes.titreResultats(gagne), "Tu gagnes la manche !")
    }

    func testPointsEtAccessibilite() {
        XCTAssertEqual(Textes.points(0), "0 point")
        XCTAssertEqual(Textes.points(30), "30 points")
        XCTAssertEqual(Textes.accessibilite(Carte(.un, .carreau)), "As de carreau, 1 point")
        XCTAssertEqual(Textes.accessibilite(nil), "Carte cachée")
    }

    func testCompteurDeTours() {
        var c = CompteurTours(nombreJoueurs: 3)
        XCTAssertEqual(c.tour, 1)
        c.noter([.tourSuivant(joueur: 1), .tourSuivant(joueur: 2)])
        XCTAssertEqual(c.tour, 1)
        c.noter([.reflexePasse(joueur: 2), .tourSuivant(joueur: 0)])
        XCTAssertEqual(c.tour, 2)
    }
}
