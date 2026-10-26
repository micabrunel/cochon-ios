import CochonMoteur
import CochonTable
import SwiftUI

/// Fin de manche : classement (plus petit total d'abord), au-dessus de la
/// table où toutes les cartes sont retournées.
struct ResultatsVue: View {
    let vue: VueJoueur
    let rejouer: () -> Void
    let accueil: () -> Void

    var body: some View {
        let lignes = Textes.resultats(vue)
        ZStack {
            Palette.framboiseSocle.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Mascotte(taille: 84).padding(.top, -56)
                Text(Textes.titreResultats(vue))
                    .font(Police.titre(28, .title))
                    .foregroundStyle(Palette.framboise)
                    .multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    ForEach(lignes, id: \.joueur) { l in
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Palette.jauneOmbre)
                                .opacity(l.gagnant ? 1 : 0)
                                .accessibilityHidden(true)
                            Text(l.nom).font(Police.etiquette(17))
                            if l.aAnnonce {
                                Text("COCHON!")
                                    .font(Police.titre(12))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 1)
                                    .background(Capsule().fill(Palette.cochonRouge))
                            }
                            Spacer()
                            Text(Textes.points(l.score)).font(Police.titre(20))
                        }
                        .foregroundStyle(l.joueur == vue.moi ? Palette.turquoiseSocle : Palette.framboiseTexte)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(l.gagnant ? Palette.jaune.opacity(0.35) : Palette.carteFondBas))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(l.nom), \(Textes.points(l.score))\(l.gagnant ? ", gagnant" : "")\(l.aAnnonce ? ", a annoncé COCHON!" : "")")
                    }
                }
                HStack(spacing: 12) {
                    Button(action: accueil) {
                        Text("Accueil").font(Police.titre(18)).foregroundStyle(Palette.jauneIcone)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bonbonJaune)
                    Button(action: rejouer) {
                        Text("Rejouer").font(Police.titre(20)).frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bonbonVert)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white))
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.framboiseTexte).offset(y: 6))
            .padding(.horizontal, 22)
        }
    }
}

/// Menu de la partie (bouton jaune en haut à gauche).
struct MenuPartie: View {
    let reprendre: () -> Void
    let regles: () -> Void
    let nouvellePartie: () -> Void
    let accueil: () -> Void
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        FeuilleAjustee(hauteurEstimee: 340) {
            Text("Pause").font(Police.titre(26)).foregroundStyle(Palette.framboise)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 14)
        } contenu: {
            boutons
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Palette.carteFondBas.ignoresSafeArea())
    }

    private var boutons: some View {
        // Côte à côte ; l'un sous l'autre aux tailles d'accessibilité.
        let disposition = tailleTexte.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 14))
                                                          : AnyLayout(HStackLayout(spacing: 12))
        return VStack(spacing: 14) {
            Button(action: reprendre) { libelle("Reprendre") }.buttonStyle(.bonbonVert)
            Button(action: regles) { libelle("Règles") }.buttonStyle(.bonbonBleu)
            disposition {
                Button(action: nouvellePartie) { libelle("Nouvelle partie", taille: 17) }.buttonStyle(.bonbonFramboise)
                Button(action: accueil) {
                    libelle("Accueil", taille: 17).foregroundStyle(Palette.jauneIcone)
                }
                .buttonStyle(.bonbonJaune)
            }
        }
    }

    private func libelle(_ t: String, taille: CGFloat = 20) -> some View {
        // « Nouvelle partie » sur une demi-largeur jusqu'au XXXL.
        Text(t).font(Police.titre(taille)).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 50)
    }
}
