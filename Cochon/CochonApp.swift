import CochonIA
import CochonTable
import SwiftUI

@main
struct CochonApp: App {
    var body: some Scene {
        WindowGroup {
            RacineVue()
        }
    }
}

/// Accueil ↔ partie, avec les réglages gardés entre deux lancements.
struct RacineVue: View {
    @AppStorage("joueurs") private var nombreJoueurs = 4
    @AppStorage("vitesse") private var vitesse: Vitesse = .normale
    @AppStorage("niveau") private var niveau: NiveauIA = .malin
    @AppStorage("montrerConnues") private var montrerConnues = false

    @State private var enPartie = false
    @State private var reglesOuvertes = false
    @State private var parametresOuverts = false

    private var reglages: Reglages {
        Reglages(nombreJoueurs: min(max(nombreJoueurs, 2), 4), vitesse: vitesse, niveau: niveau,
                 montrerConnues: montrerConnues)
    }

    var body: some View {
        ZStack {
            if enPartie {
                TableVue(reglages: reglages) {
                    withAnimation(.easeOut(duration: 0.25)) { enPartie = false }
                }
                .transition(.opacity)
            } else {
                AccueilVue(jouer: { withAnimation(.easeOut(duration: 0.25)) { enPartie = true } },
                           regles: { reglesOuvertes = true },
                           parametres: { parametresOuverts = true },
                           resume: resume)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $reglesOuvertes) { ReglesVue() }
        .sheet(isPresented: $parametresOuverts) {
            ParametresVue(nombreJoueurs: $nombreJoueurs, vitesse: $vitesse, niveau: $niveau,
                          montrerConnues: $montrerConnues) { parametresOuverts = false }
                .presentationDetents([.medium, .large])
        }
    }

    private var resume: String {
        let ordis = nombreJoueurs - 1
        let niveauTexte = niveau == .facile ? "facile" : "malin"
        return "\(ordis) ordi\(ordis > 1 ? "s" : ""), niveau \(niveauTexte), vitesse \(vitesse.nom.lowercased())"
    }
}
