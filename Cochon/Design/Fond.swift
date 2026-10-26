import SwiftUI

/// Fond de fête foraine (maquette 1) : dégradé radial jaune → orange →
/// rose, rayons blancs et paillettes.
///
/// Vigilance de Lisa (ne pas saturer de rose sur une longue partie) :
/// - le rose reste sur les bords ; le centre de la table est jaune clair ;
/// - les rayons s'effacent vers le centre (masque radial) : la pioche et la
///   défausse se lisent sur un fond calme ;
/// - rien ne tourne pendant la partie (les rayons ne bougent qu'à l'accueil,
///   et jamais avec « Réduire les animations »).
struct FondFoire: View {
    /// Centre du dégradé, en fraction de l'écran (maquette : 50 % / 46 %).
    var centre = UnitPoint(x: 0.5, y: 0.46)
    var rayonsTournent = false
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 0.72
            ZStack {
                RadialGradient(
                    stops: [
                        .init(color: Palette.fondCentre, location: 0),
                        .init(color: Palette.fondJaune, location: 0.16),
                        .init(color: Palette.fondOrange, location: 0.38),
                        .init(color: Palette.fondRose, location: 0.72),
                        .init(color: Palette.fondBord, location: 1),
                    ],
                    center: centre, startRadius: 0, endRadius: r)

                TimelineView(.animation(minimumInterval: 1 / 30, paused: !rayonsTournent || reduire)) { contexte in
                    let t = contexte.date.timeIntervalSinceReferenceDate
                    Rayons()
                        .rotationEffect(.degrees(rayonsTournent && !reduire ? (t * 4).truncatingRemainder(dividingBy: 360) : 0))
                }
                .frame(width: r * 3, height: r * 3)
                // Rayons effacés au centre : la table reste calme.
                .mask(
                    RadialGradient(colors: [.clear, .white.opacity(0.6), .white], center: .center,
                                   startRadius: r * 0.12, endRadius: r * 0.7)
                )
                .position(x: geo.size.width * centre.x, y: geo.size.height * centre.y)

                Paillettes()
            }
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Rayons blancs à 16 % : 7° pleins tous les 18°.
private struct Rayons: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = max(size.width, size.height)
            var a = 0.0
            while a < 360 {
                var p = Path()
                p.move(to: c)
                p.addArc(center: c, radius: r, startAngle: .degrees(a), endAngle: .degrees(a + 7), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(.white.opacity(0.16)))
                a += 18
            }
        }
    }
}

/// Cinq paillettes fixes, placées comme sur la maquette.
private struct Paillettes: View {
    private let points: [(CGFloat, CGFloat, CGFloat)] = [
        (30, 470, 16), (350, 210, 20), (60, 620, 12), (340, 470, 14), (190, 640, 10),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(points.indices, id: \.self) { i in
                let (x, y, t) = points[i]
                Image(systemName: "sparkle")
                    .font(.system(size: t, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .position(x: x * geo.size.width / 390, y: y * geo.size.height / 844)
            }
        }
    }
}
