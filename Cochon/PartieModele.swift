import CochonIA
import CochonMoteur
import Foundation
import Observation

/// L'arbitre d'une partie contre l'ordinateur, sur le téléphone. Il garde
/// l'état complet, n'en montre que la vue du joueur 0, et fait jouer les
/// ordinateurs à partir de leur seule vue. En ligne, ce rôle passera au
/// serveur (voir docs/MULTIJOUEUR.md) : l'écran ne changera pas.
@MainActor
@Observable
final class PartieModele {
    let humain = 0
    private(set) var etat: EtatPartie
    private(set) var journal: [String] = []
    private(set) var erreur: String?
    /// Emplacements de ma main montrés un instant (ouverture, Dame, pioche).
    private(set) var revele: Set<Int> = []
    /// Valet : ma carte choisie, en attente de la carte adverse.
    var valetMien: Int?

    var nombreJoueurs = 2
    var niveau: NiveauIA = .malin
    /// Mode test : laisser visibles les cartes que je connais.
    var montrerConnues = false

    @ObservationIgnored private var ordinateurs: [Ordinateur] = []
    @ObservationIgnored private var tache: Task<Void, Never>?
    /// Masquages différés de `revele`, un par emplacement. Annulés à chaque
    /// nouvelle manche : sinon une tâche de la manche précédente masquerait
    /// un emplacement de la suivante.
    @ObservationIgnored private var masquages: [Int: Task<Void, Never>] = [:]

    init() {
        // Remplacé tout de suite par `nouvelleManche()`.
        etat = try! Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: 2), graine: 0)
        nouvelleManche()
    }

    var vue: VueJoueur { etat.vue(pour: humain) }

    func nouvelleManche() {
        tache?.cancel()
        masquages.values.forEach { $0.cancel() }
        masquages = [:]
        let graine = UInt64.random(in: 0...UInt64.max)
        do {
            etat = try Moteur.nouvellePartie(config: ConfigPartie(nombreJoueurs: nombreJoueurs), graine: graine)
        } catch {
            erreur = "\(error)"
            return
        }
        ordinateurs = (0..<nombreJoueurs).map { Ordinateur(niveau: niveau, graine: graine &+ UInt64($0)) }
        journal = ["Nouvelle manche, graine \(graine)."]
        revele = []
        valetMien = nil
        erreur = nil
        faireJouerLesOrdinateurs()
    }

    // MARK: - Gestes du joueur

    func toucherMaCarte(_ i: Int) {
        switch vue.phase {
        case .ouverture: jouer(.regarder(emplacement: i), montrer: i)
        case .cartePiochee: jouer(.remplacer(emplacement: i), montrer: i)
        case .pouvoirDame: jouer(.regarderDame(emplacement: i), montrer: i)
        case .pouvoirValet: valetMien = i
        case .reflexe: jouer(.reflexe(emplacement: i))
        default: break
        }
    }

    func toucherCarteAdverse(joueur: Int, emplacement: Int) {
        guard vue.phase == .pouvoirValet, let mien = valetMien else { return }
        valetMien = nil
        jouer(.echangerValet(monEmplacement: mien, adversaire: joueur, sonEmplacement: emplacement))
    }

    func jouer(_ coup: Coup, montrer emplacement: Int? = nil) {
        guard appliquer(Action(joueur: humain, coup: coup)) else { return }
        if let emplacement { montrerUnInstant(emplacement) }
        faireJouerLesOrdinateurs()
    }

    // MARK: - Arbitre

    @discardableResult
    private func appliquer(_ action: Action) -> Bool {
        do {
            let r = try Moteur.appliquer(action, a: etat)
            etat = r.etat
            journal.append(contentsOf: r.evenements.map(texte).filter { !$0.isEmpty })
            erreur = nil
            return true
        } catch {
            erreur = "Coup refusé : \(error)"
            return false
        }
    }

    private func montrerUnInstant(_ emplacement: Int) {
        revele.insert(emplacement)
        // Un seul masquage en cours par emplacement : le dernier gagne.
        masquages[emplacement]?.cancel()
        masquages[emplacement] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            // `try?` avale l'annulation : sans ce test, une tâche annulée
            // masquerait quand même l'emplacement.
            if Task.isCancelled { return }
            self?.revele.remove(emplacement)
            self?.masquages[emplacement] = nil
        }
    }

    private func faireJouerLesOrdinateurs() {
        tache?.cancel()
        tache = Task { [weak self] in
            while !Task.isCancelled {
                guard let modele = self, let suivant = modele.prochainCoupOrdinateur() else { return }
                try? await Task.sleep(nanoseconds: 450_000_000)
                if Task.isCancelled { return }
                modele.appliquer(suivant)
            }
        }
    }

    private func prochainCoupOrdinateur() -> Action? {
        for j in 0..<etat.nombreJoueurs where j != humain {
            if let coup = ordinateurs[j].choisir(etat.vue(pour: j)) { return Action(joueur: j, coup: coup) }
        }
        return nil
    }

    // MARK: - Textes

    func nom(_ j: Int) -> String { j == humain ? "Vous" : "Ordi \(j)" }

    private func texte(_ e: Evenement) -> String {
        switch e {
        case .regardOuverture(let j, let i): return "\(nom(j)) regarde sa carte \(i + 1)."
        case .debutDuJeu(let p): return "La partie commence : \(nom(p)) joue."
        case .pioche(let j, .pioche, _): return "\(nom(j)) pioche."
        case .pioche(let j, .defausse, let c): return "\(nom(j)) prend \(c.map(\.description) ?? "la défausse")."
        case .remplacement(let j, let i, let c): return "\(nom(j)) remplace sa carte \(i + 1) ; \(c) part à la défausse."
        case .defausse(let j, let c): return "\(nom(j)) défausse \(c)."
        case .pouvoirSaute(let j, let c): return "\(nom(j)) : \(c) sans cible, pouvoir perdu."
        case .echangeValet(let j, let a, let adv, let b):
            return "\(nom(j)) échange sa carte \(a + 1) avec la carte \(b + 1) de \(nom(adv))."
        case .regardDame(let j, let i): return "\(nom(j)) regarde sa carte \(i + 1)."
        case .reflexeReussi(let j, _, let c): return "Réflexe réussi : \(nom(j)) écarte \(c)."
        case .reflexeRate(let j, _, let c, let p): return "Réflexe raté (\(c)) : \(p ? "une carte de pénalité pour" : "pas de pénalité, pioche vide,") \(nom(j))."
        case .reflexePasse: return ""
        case .tourSuivant(let j): return "Au tour de \(nom(j))."
        case .cochon(let j, let n): return "COCHON! annoncé par \(nom(j)). Dernière orbite : \(n) tour(s)."
        case .finDeManche(let s): return "Fin de manche : " + s.enumerated().map { "\(nom($0)) \($1)" }.joined(separator: ", ") + "."
        }
    }
}
