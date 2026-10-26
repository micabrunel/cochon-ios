import CochonTable
import SwiftUI

/// Surimpressions éphémères : « +1 » flottant, réflexe, pouvoirs, et la
/// grande annonce COCHON! avec la mascotte.
struct CalqueAnnonces: View {
    let modele: TableModele
    let d: Disposition
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        ZStack {
            ForEach(modele.annonces) { a in
                switch a.annonce {
                case .cochon(let j, let n):
                    AnnonceCochon(texte: Textes.sousTitreCochon(j, moi: modele.moi, toursRestants: n))
                        .transition(.opacity)
                case .plusUn(let j):
                    PlusUn()
                        .position(x: d.etiquette(d.place(j)).x + 34 * d.echelle, y: d.etiquette(d.place(j)).y - 26 * d.echelle)
                        .transition(.opacity)
                default:
                    Bulle(texte: Textes.annonce(a.annonce, moi: modele.moi), ton: ton(a.annonce))
                        .position(x: d.centreTable.x, y: d.centreTable.y - 118 * d.echelle)
                        .transition(.apparition(echelle: 0.92, reduire: reduire))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func ton(_ a: Annonce) -> Bulle.Ton {
        switch a {
        case .reflexeReussi: return .succes
        case .reflexeRate, .pouvoirPerdu: return .alerte
        default: return .info
        }
    }
}

/// Bulle d'annonce courte au-dessus de la table.
struct Bulle: View {
    enum Ton { case info, succes, alerte }
    let texte: String
    let ton: Ton

    var body: some View {
        let (face, socle): (Color, Color) = {
            switch ton {
            case .info: return (Palette.framboise, Palette.framboiseSocle)
            case .succes: return (Palette.turquoise, Palette.turquoiseSocle)
            case .alerte: return (Palette.cochonRouge, Palette.framboiseSocle)
            }
        }()
        Text(texte)
            .font(Police.titre(20))
            .foregroundStyle(.white)
            .shadow(color: socle, radius: 0, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(face))
            .background(Capsule().fill(socle).offset(y: 4))
    }
}

/// « +1 » qui monte en s'effaçant près de l'étiquette du joueur pénalisé.
struct PlusUn: View {
    @State var parti = false
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        Text("+1")
            .font(Police.titre(30))
            .foregroundStyle(Palette.jaune)
            .shadow(color: Palette.framboiseSocle, radius: 0, x: 0, y: 3)
            .offset(y: parti && !reduire ? -36 : 0)
            .scaleEffect(parti || reduire ? 1 : 0.7)
            .opacity(parti ? 0 : 1)
            .onAppear {
                withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 1.0).delay(0.1)) { parti = true }
            }
            .accessibilityHidden(true)
    }
}

/// Annonce COCHON! : voile, mascotte qui surgit, titre en relief.
struct AnnonceCochon: View {
    let texte: String
    @State var arrive = false
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        ZStack {
            Palette.framboiseSocle.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 6) {
                Mascotte(taille: 120)
                    .rotationEffect(.degrees(arrive || reduire ? -6 : -24))
                Text("COCHON!")
                    .font(Police.titre(58, .largeTitle))
                    .foregroundStyle(.white)
                    .shadow(color: Palette.framboiseSocle, radius: 0, x: 0, y: 5)
                    .rotationEffect(.degrees(-6))
                Text(texte)
                    .font(Police.texte(16))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .scaleEffect(arrive || reduire ? 1 : 0.8)
            .opacity(arrive ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduire ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.35)) { arrive = true }
        }
        .accessibilityHidden(true)
    }
}
