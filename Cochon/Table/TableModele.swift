import CochonIA
import CochonMoteur
import CochonTable
import SwiftUI

/// Réglages de la partie (écran Paramètres, gardés entre deux lancements).
struct Reglages: Equatable {
    var nombreJoueurs = 4
    var vitesse: Vitesse = .normale
    var niveau: NiveauIA = .malin
    /// Pour tester : laisser visibles les cartes que je connais.
    var montrerConnues = false
}

/// Une annonce à l'écran, avec un identifiant pour l'animer et la retirer.
struct AnnonceAffichee: Identifiable, Equatable {
    let id: Int
    let annonce: Annonce
}

/// Retour haptique à jouer (l'identifiant change à chaque impulsion).
struct Impulsion: Equatable {
    let id: Int
    let type: Haptique
}

/// La table vue par l'écran. Toute la logique testable est dans
/// `CochonTable` (arbitre, plateau, chorégraphie, gestes, textes) ; ce
/// modèle ne fait que l'enchaîner dans le temps, avec les animations.
@MainActor
@Observable
final class TableModele {
    let reglages: Reglages
    private(set) var arbitre: Arbitre
    private(set) var plateau: Plateau
    /// Vue affichée : mise à jour quand les animations du coup sont finies,
    /// pour que les boutons n'apparaissent qu'au bon moment.
    private(set) var vue: VueJoueur
    private(set) var compteur: CompteurTours
    /// Animations en cours : les gestes sont ignorés.
    private(set) var occupe = true
    private(set) var distributionFaite = false
    private(set) var annonces: [AnnonceAffichee] = []
    private(set) var impulsion: Impulsion?
    /// Incrémenté à chaque « À toi ! » : le bandeau rebondit.
    private(set) var appelsATour = 0
    private(set) var resultatsVisibles = false
    var valetMien: Int?
    var attenteRemplacement = false
    var rythme: Rythme

    @ObservationIgnored private var tache: Task<Void, Never>?
    @ObservationIgnored private var compteurIds = 0

    init(reglages: Reglages) {
        self.reglages = reglages
        rythme = Rythme(vitesse: reglages.vitesse)
        let config = ConfigPartie(nombreJoueurs: reglages.nombreJoueurs)
        // 2 à 4 joueurs : la configuration est toujours valide.
        let a = try! Arbitre(config: config, niveau: reglages.niveau, graine: UInt64.random(in: 0...UInt64.max))
        arbitre = a
        plateau = Plateau(nombreJoueurs: reglages.nombreJoueurs)
        vue = a.vue
        compteur = CompteurTours(nombreJoueurs: reglages.nombreJoueurs)
    }

    var moi: Int { arbitre.moi }
    var commandes: Commandes {
        guard !occupe else { return Commandes() }
        return Intentions.commandes(vue, valetMien: valetMien)
    }

    var jetons: [JetonAffiche] { plateau.jetonsAffiches(toutMontrer: reglages.montrerConnues) }

    // MARK: - Déroulé

    /// Distribution animée, puis les ordinateurs regardent leurs 2 cartes
    /// tous en même temps : le joueur n'attend pas pour regarder les siennes.
    func demarrer() {
        guard tache == nil else { return }
        tache = Task { [weak self] in
            guard let self else { return }
            let etapes = Choregraphie.distribution(nombreJoueurs: vue.nombreJoueurs,
                                                   premiere: vue.defausse[0], rythme: rythme)
            await jouer(etapes)
            distributionFaite = true
            var suites: [[Etape]] = []
            while let action = arbitre.prochainCoupOrdinateur(), case .regarder = action.coup {
                guard let evenements = try? arbitre.jouerOrdinateur(action) else { break }
                suites.append(Choregraphie.etapes(pour: evenements, moi: moi, vueApres: arbitre.vue, rythme: rythme))
            }
            vue = arbitre.vue
            await jouer(Choregraphie.simultanees(suites))
            occupe = false
        }
    }

    func arreter() {
        tache?.cancel()
        tache = nil
    }

    // MARK: - Gestes

    func toucher(_ jeton: JetonAffiche) {
        switch jeton.lieu {
        case .pioche: geste(.pioche)
        case .defausse: geste(.defausse)
        case .main(let j, let i): geste(j == moi ? .maCarte(i) : .carteAdverse(joueur: j, emplacement: i))
        case .tenue: break
        }
    }

    func geste(_ g: Geste) {
        guard !occupe else { return }
        switch Intentions.reponse(g, vue: vue, valetMien: valetMien) {
        case .rien:
            break
        case .attendreRemplacement:
            attenteRemplacement = true
            vibrer(.selection)
        case .choisirValet(let i):
            withAnimation(Courbe.sortie(rythme.dureeAnimation(.soulevement))) {
                if let ancien = valetMien { plateau.appliquer(.soulever(joueur: moi, emplacement: ancien, false)) }
                plateau.appliquer(.soulever(joueur: moi, emplacement: i, true))
            }
            valetMien = i
            vibrer(.selection)
        case .jouer(let coups):
            occupe = true
            attenteRemplacement = false
            tache = Task { [weak self] in
                guard let self else { return }
                for coup in coups {
                    guard let evenements = try? arbitre.jouer(coup) else {
                        vibrer(.erreur)
                        break
                    }
                    valetMien = nil
                    await animer(evenements)
                }
                await tourDesOrdinateurs()
                occupe = false
            }
        }
    }

    // MARK: - Ordinateurs

    /// Les ordinateurs jouent tant qu'ils ont un coup, chacun à son rythme :
    /// une pause de « réflexion » avant chaque coup qui se voit.
    private func tourDesOrdinateurs() async {
        while !Task.isCancelled, let action = arbitre.prochainCoupOrdinateur() {
            let pause = rythme.pauseAvant(action.coup)
            if pause > 0 { try? await Task.sleep(for: .seconds(pause)) }
            if Task.isCancelled { return }
            guard let evenements = try? arbitre.jouerOrdinateur(action) else { return }
            await animer(evenements)
        }
    }

    // MARK: - Animation

    private func animer(_ evenements: [Evenement]) async {
        compteur.noter(evenements)
        let apres = arbitre.vue
        await jouer(Choregraphie.etapes(pour: evenements, moi: moi, vueApres: apres, rythme: rythme))
        vue = apres
        if apres.phase == .terminee && !resultatsVisibles {
            withAnimation(Courbe.sortie(0.3)) { resultatsVisibles = true }
        }
    }

    private func jouer(_ etapes: [Etape]) async {
        for e in etapes {
            if Task.isCancelled { return }
            withAnimation(animation(e.style)) { plateau.appliquer(e.mouvements) }
            if let h = e.haptique { vibrer(h) }
            if let a = e.annonce { annoncer(a) }
            let attente = max(e.attente, rythme.dureeAnimation(e.style))
            try? await Task.sleep(for: .seconds(attente))
        }
    }

    /// Courbe de chaque style (DESIGN.md, « Mouvement »). Réduire les
    /// animations : rien ne vole ni ne se soulève, les retournements
    /// deviennent des fondus.
    private func animation(_ style: StyleAnimation) -> Animation? {
        if rythme.reduire {
            return style == .retournement ? .easeInOut(duration: rythme.dureeAnimation(style)) : nil
        }
        let d = rythme.dureeAnimation(style)
        switch style {
        case .vol: return Courbe.vol(d)
        case .distribution: return Courbe.distribution(d)
        case .retournement, .croisement: return Courbe.traversee(d)
        case .soulevement: return Courbe.sortie(d)
        case .immediat: return nil
        }
    }

    private func annoncer(_ a: Annonce) {
        AccessibilityNotification.Announcement(Textes.annonce(a, moi: moi)).post()
        if a == .aToi {
            appelsATour += 1
            return
        }
        compteurIds += 1
        let affichee = AnnonceAffichee(id: compteurIds, annonce: a)
        withAnimation(Courbe.sortie(0.25)) { annonces.append(affichee) }
        let duree: Double
        switch a {
        case .cochon: duree = rythme.duree(1.7)
        case .plusUn: duree = rythme.duree(1.1)
        default: duree = rythme.duree(1.2)
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duree))
            withAnimation(Courbe.sortie(0.2)) { self?.annonces.removeAll { $0.id == affichee.id } }
        }
    }

    private func vibrer(_ h: Haptique) {
        compteurIds += 1
        impulsion = Impulsion(id: compteurIds, type: h)
    }
}
