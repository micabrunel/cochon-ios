import SwiftUI

/// La mascotte de la maquette 1 (SVG 100 × 100 du bandeau), redessinée en
/// formes SwiftUI : tête rose, oreilles pointues, joues, groin, sourire.
struct Mascotte: View {
    var taille: CGFloat = 64

    private let trait = Color(hex: 0xC94477)
    private let tete = Color(hex: 0xFFB3CB)
    private let oreille = Color(hex: 0xFF8FB4)
    private let oreilleInterieur = Color(hex: 0xFF6F9C)
    private let reflet = Color(hex: 0xFFD0DF)
    private let joue = Color(hex: 0xFF7FA6)
    private let oeil = Color(hex: 0x2B1020)
    private let narine = Color(hex: 0xA8325F)
    private let bouche = Color(hex: 0x7A2346)

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 100
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rx) * k, y: (cy - ry) * k, width: 2 * rx * k, height: 2 * ry * k))
            }
            func triangle(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ c: (CGFloat, CGFloat)) -> Path {
                var t = Path()
                t.move(to: p(a.0, a.1)); t.addLine(to: p(b.0, b.1)); t.addLine(to: p(c.0, c.1)); t.closeSubpath()
                return t
            }
            let style = StrokeStyle(lineWidth: 3 * k, lineCap: .round, lineJoin: .round)

            for o in [triangle((18, 34), (14, 8), (38, 22)), triangle((82, 34), (86, 8), (62, 22))] {
                ctx.fill(o, with: .color(oreille))
                ctx.stroke(o, with: .color(trait), style: style)
            }
            ctx.fill(triangle((20, 28), (18, 14), (31, 22)), with: .color(oreilleInterieur))
            ctx.fill(triangle((80, 28), (82, 14), (69, 22)), with: .color(oreilleInterieur))

            let visage = ellipse(50, 54, 38, 38)
            ctx.fill(visage, with: .color(tete))
            ctx.stroke(visage, with: .color(trait), style: style)
            ctx.fill(ellipse(50, 40, 26, 12), with: .color(reflet.opacity(0.7)))
            ctx.fill(ellipse(27, 62, 7, 7), with: .color(joue.opacity(0.6)))
            ctx.fill(ellipse(73, 62, 7, 7), with: .color(joue.opacity(0.6)))

            ctx.fill(ellipse(36, 46, 5, 6.5), with: .color(oeil))
            ctx.fill(ellipse(64, 46, 5, 6.5), with: .color(oeil))
            ctx.fill(ellipse(37.8, 43.5, 2, 2), with: .color(.white))
            ctx.fill(ellipse(65.8, 43.5, 2, 2), with: .color(.white))

            let groin = ellipse(50, 62, 15, 10.5)
            ctx.fill(groin, with: .color(oreille))
            ctx.stroke(groin, with: .color(trait), style: style)
            ctx.fill(ellipse(44.5, 62, 3, 4.2), with: .color(narine))
            ctx.fill(ellipse(55.5, 62, 3, 4.2), with: .color(narine))

            var sourire = Path()
            sourire.move(to: p(42, 74))
            sourire.addQuadCurve(to: p(58, 74), control: p(50, 82))
            ctx.stroke(sourire, with: .color(bouche), style: style)
        }
        .frame(width: taille, height: taille)
        .accessibilityHidden(true)
    }
}
