import CochonIA
import CochonMoteur
@testable import CochonTable
import Foundation
import XCTest

/// Mode démo (captures d'écran) : chaque écran de la table est trouvé avec
/// la graine par défaut, toujours le même, dans la situation annoncée, et
/// le plateau dessiné reste aligné sur la vue du joueur (aucune face en
/// trop).
final class DemoTests: XCTestCase {

    let tables = EcranDemo.allCases.filter(\.surLaTable)

    func testChaqueEcranDeLaTableEstTrouveAvecLaGraineParDefaut() {
        for ecran in tables {
            XCTAssertNotNil(Demo.scene(ecran), "\(ecran.rawValue) introuvable")
        }
        XCTAssertNil(Demo.scene(.accueil), "l'accueil ne se joue pas")
    }

    func testMemeGraineMemeEcran() throws {
        for ecran in tables {
            let a = try XCTUnwrap(Demo.scene(ecran)), b = try XCTUnwrap(Demo.scene(ecran))
            XCTAssertEqual(a.graine, b.graine, ecran.rawValue)
            XCTAssertEqual(a.arbitre.etat, b.arbitre.etat, ecran.rawValue)
            XCTAssertEqual(a.plateau, b.plateau, ecran.rawValue)
            XCTAssertEqual(a.annonces, b.annonces, ecran.rawValue)
        }
    }

    func testLePlateauResteAligneSurLaVue() throws {
        for ecran in tables {
            let s = try XCTUnwrap(Demo.scene(ecran))
            verifier(s.plateau, s.vue, ecran.rawValue)
            XCTAssertEqual(s.vue.nombreJoueurs, Demo.nombreJoueurs)
        }
    }

    func testChaqueEcranMontreLaBonneSituation() throws {
        func scene(_ e: EcranDemo) throws -> SceneDemo { try XCTUnwrap(Demo.scene(e), e.rawValue) }

        let regard = try scene(.regard)
        XCTAssertEqual(regard.vue.phase, .ouverture)
        XCTAssertEqual(regard.vue.regardsOuvertureRestants, 1)
        let montree = regard.plateau.jetonsAffiches().filter { $0.montree && $0.souleve }
        XCTAssertEqual(montree.count, 1, "ma carte regardée est soulevée, face visible")

        for e in [EcranDemo.monTour, .menu] {
            let s = try scene(e)
            XCTAssertTrue(s.vue.estMonTour)
            XCTAssertEqual(s.vue.phase, .choixSource)
            XCTAssertGreaterThanOrEqual(s.compteur.tour, 3)
            XCTAssertTrue(Intentions.commandes(s.vue).piochePossible)
        }

        let piochee = try scene(.cartePiochee)
        XCTAssertEqual(piochee.vue.phase.source, .pioche)
        XCTAssertNotNil(piochee.vue.cartePiochee)
        let c = Intentions.commandes(piochee.vue)
        XCTAssertTrue(c.remplacerVisible && c.defausserVisible)
        XCTAssertNotNil(Textes.legendeTenue(piochee.vue))

        let valet = try scene(.valet)
        XCTAssertEqual(valet.vue.phase, .pouvoirValet)
        XCTAssertTrue(valet.vue.estMonTour)
        XCTAssertEqual(valet.annonces, [.valet(joueur: 0)])
        let mien = try XCTUnwrap(valet.valetMien)
        XCTAssertTrue(valet.plateau.souleves.contains(valet.plateau.mains[0][mien]))
        XCTAssertTrue(Intentions.commandes(valet.vue, valetMien: mien).adversesTouchables)

        let dame = try scene(.dame)
        XCTAssertEqual(dame.annonces, [.dame(joueur: 0)])
        XCTAssertTrue(dame.occupe)
        XCTAssertEqual(dame.plateau.jetonsAffiches().filter { $0.montree && $0.souleve }.count, 1)

        let reflexe = try scene(.reflexe)
        XCTAssertEqual(reflexe.annonces, [.reflexeReussi(joueur: 0)])
        XCTAssertEqual(reflexe.vue.phase, .finDeTour)
        XCTAssertEqual(reflexe.vue.maMain.count, 3, "la carte est partie à la défausse")

        let penalite = try scene(.penalite)
        XCTAssertEqual(penalite.annonces, [.reflexeRate(joueur: 0), .plusUn(joueur: 0)])
        XCTAssertEqual(penalite.vue.maMain.count, 5, "une carte de pénalité en plus")

        let ordi = try scene(.tourOrdi)
        XCTAssertNotEqual(ordi.vue.actif, 0)
        XCTAssertEqual(ordi.plateau.tenue?.joueur, ordi.vue.actif)
        XCTAssertNil(ordi.plateau.tenue.flatMap { ordi.plateau.faces[$0.jeton] }, "la carte de l'ordi reste cachée")
        XCTAssertTrue(ordi.occupe)

        let cochon = try scene(.cochon)
        XCTAssertEqual(cochon.vue.cochonPar, 0)
        XCTAssertEqual(cochon.annonces, [.cochon(joueur: 0, toursRestants: 3)])

        let orbite = try scene(.derniereOrbite)
        XCTAssertNotNil(orbite.vue.cochonPar)
        XCTAssertNotEqual(orbite.vue.cochonPar, 0)
        XCTAssertTrue(orbite.vue.estMonTour)
        XCTAssertEqual(Textes.banniere(orbite.vue, tour: orbite.compteur.tour).detail, "Dernier tour")
        XCTAssertFalse(Intentions.commandes(orbite.vue).cochonActif)

        let fin = try scene(.resultats)
        XCTAssertTrue(fin.resultats)
        XCTAssertEqual(fin.vue.phase, .terminee)
        XCTAssertEqual(Textes.titreResultats(fin.vue), "Tu gagnes la manche !")
        XCTAssertEqual(Textes.resultats(fin.vue).first?.aAnnonce, true)
        XCTAssertTrue(fin.plateau.jetonsAffiches(profondeurVisible: 0).allSatisfy(\.montree))
    }

    func testUneAutreGraineDonneUneAutrePartie() throws {
        let a = try XCTUnwrap(Demo.scene(.monTour))
        let b = try XCTUnwrap(Demo.scene(.monTour, graine: 7))
        XCTAssertNotEqual(a.arbitre.etat, b.arbitre.etat)
    }

    func testArgumentsDeLancement() {
        XCTAssertEqual(Demo.lancement(arguments: ["Cochon"]),
                       LancementDemo(ecran: nil, nomInconnu: nil, graine: Demo.graineParDefaut))
        XCTAssertFalse(Demo.lancement(arguments: ["Cochon"]).actif)
        XCTAssertEqual(Demo.lancement(arguments: ["Cochon", "-ecran", "carte-piochee", "-graine", "12"]),
                       LancementDemo(ecran: .cartePiochee, nomInconnu: nil, graine: 12))
        let inconnu = Demo.lancement(arguments: ["Cochon", "-ecran", "nimporte"])
        XCTAssertEqual(inconnu.nomInconnu, "nimporte")
        XCTAssertTrue(inconnu.actif)
        XCTAssertEqual(Demo.lancement(arguments: ["-ecran"]).ecran, nil, "valeur manquante")
        XCTAssertEqual(Demo.lancement(arguments: ["-ecran", "menu", "-graine", "x"]).graine, Demo.graineParDefaut)
    }

    /// Le script de captures parcourt exactement les écrans du mode démo,
    /// dans le même ordre.
    func testLeScriptDeCapturesConnaitTousLesEcrans() throws {
        let racine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: racine.appendingPathComponent("scripts/captures-ecrans.sh"), encoding: .utf8)
        let ligne = try XCTUnwrap(script.split(separator: "\n").first { $0.hasPrefix("ECRANS=(") })
        let noms = ligne.dropFirst("ECRANS=(".count).prefix { $0 != ")" }.split(separator: " ").map(String.init)
        XCTAssertEqual(noms, EcranDemo.allCases.map(\.rawValue))
    }

    // MARK: - Outils

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

private extension VuePhase {
    var source: Source? {
        if case .cartePiochee(_, let s) = self { return s }
        return nil
    }
}
