import CochonMoteur
import CochonTable
import SwiftUI

// Cartes de la maquette 1 : dos rose à rayons avec groin jaune, face
// blanche en Lilita One. Toutes les cotes sont proportionnelles à la
// largeur (carte de 56 pt : bord 3 pt, rayon 9 pt).

private func rayonCarte(_ largeur: CGFloat) -> CGFloat { max(5, largeur * 0.13) }
private func bordCarte(_ largeur: CGFloat) -> CGFloat { max(2, largeur * 0.054) }

/// Dos de carte : rayons rose clair / rose vif (24 secteurs), bord blanc,
/// groin jaune penché de -12°.
struct DosCarte: View {
    let largeur: CGFloat

    private static let rayons: Gradient = {
        var stops: [Gradient.Stop] = []
        for k in 0..<24 {
            let c = k.isMultiple(of: 2) ? Palette.roseRayonClair : Palette.roseRayonFonce
            stops.append(.init(color: c, location: Double(k) / 24))
            stops.append(.init(color: c, location: Double(k + 1) / 24))
        }
        return Gradient(stops: stops)
    }()

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: rayonCarte(largeur), style: .continuous)
        ZStack {
            forme.fill(AngularGradient(gradient: Self.rayons, center: .center))
            Groin(largeur: largeur * 0.62)
                .rotationEffect(.degrees(-12))
        }
        .clipShape(forme)
        .overlay(forme.strokeBorder(.white, lineWidth: bordCarte(largeur)))
    }
}

/// Le groin : ellipse jaune bordée de blanc, deux narines framboise.
struct Groin: View {
    let largeur: CGFloat

    var body: some View {
        let hauteur = largeur / 1.3
        ZStack {
            Ellipse().fill(Palette.roseOmbre).offset(y: max(1, largeur * 0.05))
            Ellipse().fill(Palette.jaune)
            Ellipse().strokeBorder(.white, lineWidth: max(1, largeur * 0.06))
            HStack(spacing: largeur * 0.16) {
                Ellipse().fill(Palette.framboise).frame(width: largeur * 0.2, height: hauteur * 0.44)
                Ellipse().fill(Palette.framboise).frame(width: largeur * 0.2, height: hauteur * 0.44)
            }
        }
        .frame(width: largeur, height: hauteur)
    }
}

/// Face d'une carte : index en haut à gauche et en bas à droite (retourné),
/// grande valeur au centre. Rouge #E8173F, noir #1D1A3A.
struct FaceCarte: View {
    let carte: Carte
    let largeur: CGFloat

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: rayonCarte(largeur), style: .continuous)
        let encre = carte.couleur.estRouge ? Palette.carteRouge : Palette.encre
        ZStack {
            forme.fill(LinearGradient(colors: [.white, Palette.carteFondBas], startPoint: .top, endPoint: .bottom))
            VStack(spacing: -largeur * 0.08) {
                Text(carte.rang.code).font(Police.carte(largeur * 0.56))
                Text(carte.couleur.symbole).font(Police.carte(largeur * 0.4))
            }
            index.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, largeur * 0.08).padding(.top, largeur * 0.06)
            index.rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, largeur * 0.08).padding(.bottom, largeur * 0.06)
        }
        .foregroundStyle(encre)
        .clipShape(forme)
        .overlay(forme.strokeBorder(.white, lineWidth: bordCarte(largeur)))
    }

    private var index: some View {
        VStack(spacing: -largeur * 0.03) {
            Text(carte.rang.code).font(Police.carte(largeur * 0.2))
            Text(carte.couleur.symbole).font(Police.carte(largeur * 0.17))
        }
    }
}

/// Carte qui se retourne en 3D (axe vertical). Avec « Réduire les
/// animations », le retournement devient un fondu.
struct CarteRetournable: View {
    let face: Carte?
    let montree: Bool
    let taille: CGSize
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        let visible = montree && face != nil
        Group {
            if reduire {
                ZStack {
                    if visible, let face { FaceCarte(carte: face, largeur: taille.width).transition(.opacity) }
                    else { DosCarte(largeur: taille.width).transition(.opacity) }
                }
            } else {
                Color.clear.modifier(Retournement(angle: visible ? 0 : 180, face: face, largeur: taille.width))
            }
        }
        .frame(width: taille.width, height: taille.height)
        .shadow(color: Palette.ombreCarte.opacity(0.35), radius: 0, x: 0, y: 3)
        .shadow(color: Palette.ombreCarte.opacity(0.3), radius: 4, x: 0, y: 4)
    }
}

/// Montre la face tant que l'angle est sous 90°, le dos au-delà : la carte
/// change de côté au moment où elle est vue de profil.
private struct Retournement: ViewModifier, Animatable {
    var angle: Double
    let face: Carte?
    let largeur: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        ZStack {
            if angle < 90, let face {
                FaceCarte(carte: face, largeur: largeur)
            } else {
                DosCarte(largeur: largeur).scaleEffect(x: -1, y: 1)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}
