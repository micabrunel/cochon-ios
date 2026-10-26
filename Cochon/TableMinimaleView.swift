import CochonIA
import CochonMoteur
import SwiftUI

/// Écran de vérification du moteur, volontairement sobre : la vraie table
/// sera dessinée d'après la maquette choisie par Michael. Il permet de
/// jouer une manche entière contre 1 à 3 ordinateurs.
struct TableMinimaleView: View {
    @State private var partie = PartieModele()

    var body: some View {
        let vue = partie.vue
        VStack(spacing: 12) {
            reglages
            adversaires(vue)
            centre(vue)
            Text(consigne(vue))
                .font(.headline)
                .multilineTextAlignment(.center)
            maMain(vue)
            boutons(vue)
            if let erreur = partie.erreur {
                Text(erreur).font(.footnote).foregroundStyle(.red)
            }
            journal
        }
        .padding()
    }

    // MARK: - Morceaux

    private var reglages: some View {
        HStack {
            Picker("Joueurs", selection: $partie.nombreJoueurs) {
                ForEach(2...4, id: \.self) { Text("\($0) joueurs").tag($0) }
            }
            Picker("Niveau", selection: $partie.niveau) {
                Text("Facile").tag(NiveauIA.facile)
                Text("Malin").tag(NiveauIA.malin)
            }
            Button("Nouvelle manche") { partie.nouvelleManche() }
                .buttonStyle(.bordered)
            Toggle("Test", isOn: $partie.montrerConnues)
                .toggleStyle(.button)
        }
        .font(.footnote)
    }

    private func adversaires(_ vue: VueJoueur) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<vue.nombreJoueurs, id: \.self) { j in
                if j != partie.humain {
                    VStack(spacing: 4) {
                        Text(vue.actif == j ? partie.nom(j) + " ●" : partie.nom(j))
                            .font(.caption.bold())
                        HStack(spacing: 3) {
                            ForEach(Array(vue.mains[j].enumerated()), id: \.offset) { i, carte in
                                CarteView(carte: visibleAdverse(carte, vue), petite: true)
                                    .onTapGesture { partie.toucherCarteAdverse(joueur: j, emplacement: i) }
                            }
                        }
                        if let s = vue.scores { Text("\(s[j]) pts").font(.caption) }
                    }
                }
            }
        }
    }

    private func centre(_ vue: VueJoueur) -> some View {
        HStack(spacing: 24) {
            VStack {
                CarteView(carte: nil)
                    .onTapGesture { partie.jouer(.piocher(source: .pioche)) }
                Text("Pioche (\(vue.cartesDansPioche))").font(.caption)
            }
            VStack {
                CarteView(carte: vue.dessusDefausse)
                    .onTapGesture { partie.jouer(.piocher(source: .defausse)) }
                Text("Défausse").font(.caption)
            }
            if case .cartePiochee(let carte, _) = vue.phase {
                VStack {
                    CarteView(carte: carte)
                    Text(vue.actif == partie.humain ? "Votre carte" : "\(partie.nom(vue.actif)) tient")
                        .font(.caption)
                }
            }
        }
    }

    private func maMain(_ vue: VueJoueur) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(Array(vue.maMain.enumerated()), id: \.offset) { i, carte in
                    CarteView(carte: visibleMienne(i, carte, vue))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(partie.valetMien == i ? Color.orange : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture { partie.toucherMaCarte(i) }
                }
            }
            Text(etiquetteMoi(vue))
                .font(.caption.bold())
        }
    }

    @ViewBuilder
    private func boutons(_ vue: VueJoueur) -> some View {
        let possibles = vue.coupsPossibles
        HStack {
            if possibles.contains(.defausserPiochee) {
                Button("Défausser") { partie.jouer(.defausserPiochee) }
            }
            if possibles.contains(.passerReflexe) {
                Button("Passer le réflexe") { partie.jouer(.passerReflexe) }
            }
            if possibles.contains(.terminerTour) {
                Button("Terminer le tour") { partie.jouer(.terminerTour) }
            }
            if possibles.contains(.annoncerCochon) {
                Button("COCHON!") { partie.jouer(.annoncerCochon) }
                    .tint(.pink)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private var journal: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(partie.journal.enumerated()), id: \.offset) { i, ligne in
                        Text(ligne).font(.caption2).id(i)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: partie.journal.count) { _, n in proxy.scrollTo(n - 1) }
        }
    }

    // MARK: - Ce qu'on montre

    /// Le jeu est un jeu de mémoire : une carte connue ne reste visible
    /// qu'un instant, sauf en mode test ou en fin de manche.
    private func visibleMienne(_ i: Int, _ carte: Carte?, _ vue: VueJoueur) -> Carte? {
        guard let carte else { return nil }
        return vue.phase == .terminee || partie.montrerConnues || partie.revele.contains(i) ? carte : nil
    }

    private func visibleAdverse(_ carte: Carte?, _ vue: VueJoueur) -> Carte? {
        vue.phase == .terminee || partie.montrerConnues ? carte : nil
    }

    private func etiquetteMoi(_ vue: VueJoueur) -> String {
        var texte = "Vous"
        if vue.actif == partie.humain { texte += " ●" }
        if let s = vue.scores { texte += " — \(s[partie.humain]) pts" }
        return texte
    }

    private func consigne(_ vue: VueJoueur) -> String {
        switch vue.phase {
        case .ouverture:
            return vue.regardsOuvertureRestants > 0
                ? "Touchez \(vue.regardsOuvertureRestants) de vos cartes pour la mémoriser."
                : "Les autres regardent leurs cartes…"
        case .terminee:
            let s = vue.scores ?? []
            let mini = s.min() ?? 0
            let gagnants = s.indices.filter { s[$0] == mini }.map(partie.nom)
            return "Manche finie. Gagnant : " + gagnants.joined(separator: ", ")
        default:
            break
        }
        guard vue.actif == partie.humain else { return "\(partie.nom(vue.actif)) joue…" }
        switch vue.phase {
        case .choixSource: return "Piochez ou prenez la défausse."
        case .cartePiochee(_, .defausse): return "Touchez la carte à remplacer."
        case .cartePiochee: return "Remplacez une carte, ou défaussez."
        case .pouvoirValet:
            return partie.valetMien == nil ? "Valet : touchez votre carte à échanger." : "Puis la carte adverse."
        case .pouvoirDame: return "Dame : touchez une carte pour la regarder."
        case .reflexe: return "Réflexe ? Touchez une carte du rang de la défausse, ou passez."
        case .finDeTour: return vue.cochonPar == nil ? "Terminez le tour ou annoncez COCHON!" : "Terminez le tour."
        default: return ""
        }
    }
}

struct CarteView: View {
    let carte: Carte?
    var petite = false

    var body: some View {
        let largeur: CGFloat = petite ? 30 : 56
        ZStack {
            RoundedRectangle(cornerRadius: petite ? 4 : 8)
                .fill(carte == nil ? Color.indigo : Color.white)
            RoundedRectangle(cornerRadius: petite ? 4 : 8)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
            if let carte {
                Text(carte.description)
                    .font(petite ? .caption2.bold() : .title3.bold())
                    .foregroundStyle(carte.couleur.estRouge ? Color.red : Color.black)
            }
        }
        .frame(width: largeur, height: largeur * 1.4)
        .accessibilityLabel(carte.map { "\($0.description)" } ?? "carte cachée")
    }
}
