import CochonIA
import CochonTable
import SwiftUI

/// Écran d'accueil : Jouer, Règles, Paramètres.
struct AccueilVue: View {
    let jouer: () -> Void
    let regles: () -> Void
    let parametres: () -> Void
    let resume: String
    @State var arrive = false
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        ZStack {
            // Le seul endroit où les rayons tournent (lentement).
            FondFoire(centre: UnitPoint(x: 0.5, y: 0.34), rayonsTournent: true)
            VStack(spacing: 18) {
                Spacer()
                Mascotte(taille: 150)
                    .offset(y: arrive || reduire ? 0 : -30)
                    .rotationEffect(.degrees(arrive || reduire ? -6 : 8))
                Text("COCHON!")
                    .font(Police.titre(64, .largeTitle))
                    .foregroundStyle(.white)
                    .shadow(color: Palette.framboiseSocle, radius: 0, x: 0, y: 6)
                    .rotationEffect(.degrees(-4))
                    .accessibilityAddTraits(.isHeader)
                Text("Cache tes cartes, garde le plus petit total.")
                    .font(Police.texte(17))
                    .foregroundStyle(Palette.prune)
                    .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: 14) {
                    Button(action: jouer) {
                        Text("Jouer").font(Police.titre(30)).frame(maxWidth: .infinity, minHeight: 66)
                    }
                    .buttonStyle(.bonbonVert)
                    .accessibilityHint(resume)
                    HStack(spacing: 14) {
                        Button(action: regles) {
                            Text("Règles").font(Police.titre(20)).frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bonbonBleu)
                        Button(action: parametres) {
                            Text("Paramètres").font(Police.titre(20)).foregroundStyle(Palette.jauneIcone)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bonbonJaune)
                    }
                    Text(resume)
                        .font(Police.texte(14))
                        .foregroundStyle(.white)
                        .shadow(color: Palette.framboiseSocle.opacity(0.6), radius: 0, x: 0, y: 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(reduire ? nil : .spring(duration: 0.6, bounce: 0.4)) { arrive = true }
        }
    }
}

/// Paramètres : nombre de joueurs, vitesse, niveau des ordis.
struct ParametresVue: View {
    @Binding var nombreJoueurs: Int
    @Binding var vitesse: Vitesse
    @Binding var niveau: NiveauIA
    @Binding var montrerConnues: Bool
    let fermer: () -> Void
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        // En-tête fixe (titre + OK toujours visibles), réglages en dessous ;
        // la feuille prend leur hauteur (voir FeuilleAjustee).
        FeuilleAjustee(hauteurEstimee: 560) {
            HStack {
                Text("Paramètres").font(Police.titre(28)).foregroundStyle(Palette.framboise)
                    .lineLimit(1).minimumScaleFactor(0.5) // jamais coupé en plein mot
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: fermer) {
                    Text("OK").font(Police.titre(18)).frame(minWidth: 64, minHeight: 40)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bonbonVert)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
        } contenu: {
            reglages
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 24)
        }
        .background(Palette.carteFondBas.ignoresSafeArea())
    }

    private var reglages: some View {
        VStack(alignment: .leading, spacing: 22) {
            groupe("Joueurs", options: [2, 3, 4], choix: $nombreJoueurs) { "\($0)" }
            Text(nombreJoueurs == 2 ? "Toi contre 1 ordi" : "Toi contre \(nombreJoueurs - 1) ordis")
                .font(Police.texte(14)).foregroundStyle(Palette.prune).padding(.top, -14)
            groupe("Vitesse", options: Vitesse.allCases, choix: $vitesse) { $0.nom }
            groupe("Ordis", options: NiveauIA.allCases, choix: $niveau) { $0 == .facile ? "Facile" : "Malin" }
            Toggle(isOn: $montrerConnues) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mode test").font(Police.etiquette(16)).foregroundStyle(Palette.framboiseTexte)
                    Text("Laisse visibles les cartes que tu connais.").font(Police.texte(13)).foregroundStyle(Palette.prune)
                }
            }
            .tint(Palette.turquoise)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupe<T: Hashable>(_ titre: String, options: [T], choix: Binding<T>,
                                     libelle: @escaping (T) -> String) -> some View {
        // En ligne ; en colonne aux tailles d'accessibilité, où « Tranquille »
        // ne tient plus sur un tiers de largeur.
        let disposition = tailleTexte.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10))
                                                          : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 8) {
            Text(titre).font(Police.etiquette(16)).foregroundStyle(Palette.framboiseTexte)
            disposition {
                ForEach(options, id: \.self) { o in
                    let actif = choix.wrappedValue == o
                    Button { choix.wrappedValue = o } label: {
                        Text(libelle(o))
                            .font(Police.titre(18))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 4)
                            .foregroundStyle(actif ? .white : Palette.framboiseTexte)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(actif ? BoutonBonbon(face: Palette.turquoise, ombreInterne: Palette.turquoiseOmbre,
                                                       socle: Palette.turquoiseSocle, rayon: 14, profondeur: 4)
                                       : BoutonBonbon(face: .white, ombreInterne: Color(hex: 0xF3D9E3),
                                                      socle: Color(hex: 0xE2B6C8), rayon: 14, profondeur: 4))
                    .accessibilityAddTraits(actif ? .isSelected : [])
                }
            }
        }
    }
}
