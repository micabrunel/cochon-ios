import SwiftUI

// Jetons de la maquette 1 « Fête foraine » (DESIGN.md). Toute couleur,
// police, ombre de l'app vient d'ici : ne pas en inventer ailleurs.

extension Color {
    init(hex: UInt32, opacite: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacite)
    }
}

enum Palette {
    // Fond de fête foraine, du centre vers les bords.
    static let fondCentre = Color(hex: 0xFFF7A8)
    static let fondJaune = Color(hex: 0xFFD23F)
    static let fondOrange = Color(hex: 0xFF9A1F)
    static let fondRose = Color(hex: 0xFF3D6E)
    static let fondBord = Color(hex: 0xD4126A)

    // Rose bonbon : dos de carte, compteurs.
    static let rose = Color(hex: 0xFF3D7F)
    static let roseRayonClair = Color(hex: 0xFF5C96)
    static let roseRayonFonce = Color(hex: 0xFF2F73)
    static let roseOmbre = Color(hex: 0xB3003F)
    // Framboise : étiquettes des tas, légende, texte des étiquettes.
    static let framboise = Color(hex: 0xC4135A)
    static let framboiseTexte = Color(hex: 0xB3104F)
    static let framboiseSocle = Color(hex: 0x7A0A2C)
    static let prune = Color(hex: 0x5A0D2E)

    // Jaune : menu, groin, flèches.
    static let jaune = Color(hex: 0xFFE14D)
    static let jauneOmbre = Color(hex: 0xF0A400)
    static let jauneSocle = Color(hex: 0x8E0E44)
    static let jauneIcone = Color(hex: 0xA3124E)
    static let fleche = Color(hex: 0xFFF36B)

    // Turquoise : « à toi », joueur actif.
    static let turquoise = Color(hex: 0x1FC7B6)
    static let turquoiseOmbre = Color(hex: 0x0F9C8E)
    static let turquoiseSocle = Color(hex: 0x0A6E64)

    // Actions.
    static let vert = Color(hex: 0x2FD06A)
    static let vertOmbre = Color(hex: 0x19A14B)
    static let vertSocle = Color(hex: 0x0F6E31)
    static let bleu = Color(hex: 0x2E8BFF)
    static let bleuOmbre = Color(hex: 0x1663D0)
    static let bleuSocle = Color(hex: 0x0C3F8F)

    // Bouton COCHON!.
    static let cochonClair = Color(hex: 0xFF7AA6)
    static let cochonRouge = Color(hex: 0xE8174F)
    static let cochonOmbre = Color(hex: 0xA80F3D)

    // Cartes.
    static let carteRouge = Color(hex: 0xE8173F)
    static let encre = Color(hex: 0x1D1A3A)
    static let carteFondBas = Color(hex: 0xFFF4F7)
    /// Ombre des cartes : rgba(120, 0, 50).
    static let ombreCarte = Color(red: 120 / 255, green: 0, blue: 50 / 255)
}

enum Police {
    /// Lilita One : titres, valeurs des cartes, boutons, COCHON!.
    static func titre(_ taille: CGFloat, _ style: Font.TextStyle = .title2) -> Font {
        .custom("LilitaOne", size: taille, relativeTo: style)
    }

    /// Baloo 2 Bold : légendes, consignes.
    static func texte(_ taille: CGFloat, _ style: Font.TextStyle = .subheadline) -> Font {
        .custom("Baloo2-Bold", size: taille, relativeTo: style)
    }

    /// Baloo 2 ExtraBold : étiquettes des joueurs, badges.
    static func etiquette(_ taille: CGFloat, _ style: Font.TextStyle = .footnote) -> Font {
        .custom("Baloo2-ExtraBold", size: taille, relativeTo: style)
    }

    /// Lilita One à taille fixe : valeurs des cartes (la carte ne grandit pas avec Dynamic Type).
    static func carte(_ taille: CGFloat) -> Font { .custom("LilitaOne", fixedSize: taille) }
}

/// Courbes de mouvement (DESIGN.md, « Mouvement »).
enum Courbe {
    /// Sortie franche : réponses de l'interface, soulèvements.
    static func sortie(_ d: Double) -> Animation { .timingCurve(0.23, 1, 0.32, 1, duration: d) }
    /// Mouvement à l'écran : retournement, croisement.
    static func traversee(_ d: Double) -> Animation { .timingCurve(0.77, 0, 0.175, 1, duration: d) }
    /// Vol d'une carte : ressort sans rebond, interrompable.
    static func vol(_ d: Double) -> Animation { .spring(duration: d, bounce: 0.08) }
    /// Distribution : vol vif, très léger rebond à l'arrivée.
    static func distribution(_ d: Double) -> Animation { .spring(duration: d, bounce: 0.18) }
}

// MARK: - Relief « bonbon »

/// Bouton en relief de la maquette : face, bande sombre en bas, reflet
/// en haut, socle plein décalé et ombre douce. Enfoncé : le bouton
/// descend sur son socle.
struct BoutonBonbon: ButtonStyle {
    var face: Color
    var ombreInterne: Color
    var socle: Color
    var rayon: CGFloat = 20
    var profondeur: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let enfonce = configuration.isPressed
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        configuration.label
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
            .padding(.bottom, 4)
            .background {
                forme.fill(ombreInterne)
                    .overlay(alignment: .top) {
                        forme.fill(face).padding(.bottom, 6)
                    }
                    .overlay {
                        forme.strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.45), .clear],
                                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.18)),
                            lineWidth: 3)
                    }
            }
            .offset(y: enfonce ? profondeur * 0.6 : 0)
            .background {
                forme.fill(socle).offset(y: profondeur)
                    .shadow(color: socle.opacity(0.35), radius: 7, x: 0, y: 7)
            }
            .scaleEffect(enfonce ? 0.97 : 1)
            .animation(Courbe.sortie(0.14), value: enfonce)
    }
}

extension ButtonStyle where Self == BoutonBonbon {
    static var bonbonVert: BoutonBonbon { BoutonBonbon(face: Palette.vert, ombreInterne: Palette.vertOmbre, socle: Palette.vertSocle) }
    static var bonbonBleu: BoutonBonbon { BoutonBonbon(face: Palette.bleu, ombreInterne: Palette.bleuOmbre, socle: Palette.bleuSocle) }
    static var bonbonJaune: BoutonBonbon {
        BoutonBonbon(face: Palette.jaune, ombreInterne: Palette.jauneOmbre, socle: Palette.jauneSocle, rayon: 14, profondeur: 4)
    }
    static var bonbonFramboise: BoutonBonbon {
        BoutonBonbon(face: Palette.framboise, ombreInterne: Palette.framboiseTexte, socle: Palette.framboiseSocle)
    }
}

/// Pastille de texte en relief (légendes « Pioche », « Défausse », consignes).
struct Pastille: View {
    let texte: String
    var taille: CGFloat = 14

    var body: some View {
        Text(texte)
            .font(Police.texte(taille))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(Capsule().fill(Palette.framboise))
            .background(Capsule().fill(Palette.framboiseSocle).offset(y: 3))
    }
}
