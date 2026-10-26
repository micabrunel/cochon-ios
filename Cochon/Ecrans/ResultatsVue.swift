import CochonMoteur
import CochonTable
import SwiftUI

/// Fin de manche : classement (plus petit total d'abord), au-dessus de la
/// table où toutes les cartes sont retournées.
struct ResultatsVue: View {
    let vue: VueJoueur
    let rejouer: () -> Void
    let accueil: () -> Void
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let lignes = Textes.resultats(vue)
        let grand = tailleTexte.isAccessibilitySize
        ZStack {
            Palette.framboiseSocle.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Mascotte(taille: 84).padding(.top, -56)
                Text(Textes.titreResultats(vue))
                    .font(Police.titre(28, .title))
                    .foregroundStyle(Palette.framboise)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // Le classement défile s'il ne tient plus (tailles
                // d'accessibilité) ; le titre et les boutons restent visibles.
                ViewThatFits(in: .vertical) {
                    classement(lignes, grand: grand)
                    ScrollView { classement(lignes, grand: grand) }
                        .scrollBounceBehavior(.basedOnSize)
                }
                // Côte à côte ; l'un sous l'autre aux tailles d'accessibilité
                // (sinon « Rejoue / r » sur deux lignes).
                let disposition = grand ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 12))
                disposition {
                    Button(action: accueil) {
                        libelle("Accueil", taille: 18).foregroundStyle(Palette.jauneIcone)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bonbonJaune)
                    Button(action: rejouer) {
                        libelle("Rejouer", taille: 20).frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bonbonVert)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white))
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.framboiseTexte).offset(y: 6))
            .padding(.horizontal, 22)
            // Place pour la mascotte qui dépasse du haut de la carte quand
            // celle-ci prend toute la hauteur.
            .padding(.top, grand ? 36 : 0)
            .padding(.bottom, grand ? 10 : 0)
        }
    }

    private func classement(_ lignes: [Textes.LigneResultat], grand: Bool) -> some View {
        VStack(spacing: 8) {
            ForEach(lignes, id: \.joueur) { l in
                ligne(l, grand: grand)
                    .foregroundStyle(l.joueur == vue.moi ? Palette.turquoiseSocle : Palette.framboiseTexte)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(l.gagnant ? Palette.jaune.opacity(0.35) : Palette.carteFondBas))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(l.nom), \(Textes.points(l.score))\(l.gagnant ? ", gagnant" : "")\(l.aAnnonce ? ", a annoncé COCHON!" : "")")
            }
        }
    }

    /// Une ligne : couronne, nom, pastille, points. Aux tailles
    /// d'accessibilité, en deux lignes (nom au-dessus, points en dessous)
    /// au lieu de « O… 16… ».
    @ViewBuilder
    private func ligne(_ l: Textes.LigneResultat, grand: Bool) -> some View {
        let nom = Text(l.nom).font(Police.etiquette(17)).lineLimit(1).minimumScaleFactor(0.6)
        let points = Text(Textes.points(l.score)).font(Police.titre(20)).lineLimit(1).minimumScaleFactor(0.6)
        if grand {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if l.gagnant { couronne }
                    nom
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    if l.aAnnonce { pastille }
                    Spacer(minLength: 0)
                    points
                }
            }
        } else {
            HStack(spacing: 10) {
                couronne.opacity(l.gagnant ? 1 : 0)
                nom
                if l.aAnnonce { pastille }
                Spacer()
                points
            }
        }
    }

    // Couronne et pastille : décor à cotes fixes, plafonnés au XXXL.
    private var couronne: some View {
        Image(systemName: "crown.fill")
            .foregroundStyle(Palette.jauneOmbre)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }

    private var pastille: some View {
        Text("COCHON!")
            .font(Police.titre(12))
            .lineLimit(1)
            .fixedSize() // jamais « CO / C… » écrasé
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 1)
            .background(Capsule().fill(Palette.cochonRouge))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func libelle(_ t: String, taille: CGFloat) -> some View {
        Text(t).font(Police.titre(taille)).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 6)
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
