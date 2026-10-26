// Planche récapitulative des captures : une grille de vignettes légendées.
// Lancé par scripts/captures-ecrans.sh, sur macOS seulement :
//
//   xcrun swift scripts/planche.swift <planche.png> "<titre>" <capture.png>…
//
// CoreGraphics, CoreText et ImageIO uniquement (rien à installer).

import CoreGraphics
import CoreText
import Foundation
import ImageIO

func echec(_ message: String) -> Never {
    FileHandle.standardError.write(Data("planche : \(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3 else { echec("usage : planche.swift <sortie.png> <titre> <capture.png>…") }
let sortie = URL(fileURLWithPath: arguments[0])
let titre = arguments[1]
let fichiers = arguments.dropFirst(2).map { URL(fileURLWithPath: $0) }

func charger(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

let images: [(nom: String, image: CGImage)] = fichiers.map { url in
    guard let image = charger(url) else { echec("image illisible : \(url.path)") }
    return (url.deletingPathExtension().lastPathComponent, image)
}

// Mise en page : 5 colonnes de vignettes de 300 pt de large.
let colonnes = min(5, images.count)
let lignes = (images.count + colonnes - 1) / colonnes
let largeur: CGFloat = 300
let ratio = CGFloat(images[0].image.height) / CGFloat(images[0].image.width)
let hauteur = (largeur * ratio).rounded()
let marge: CGFloat = 28, legende: CGFloat = 44, entete: CGFloat = 84
let W = marge + CGFloat(colonnes) * (largeur + marge)
let H = entete + CGFloat(lignes) * (hauteur + legende + marge) + marge

guard let espace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                          space: espace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { echec("contexte graphique impossible") }

let fond = CGColor(srgbRed: 1, green: 0.953, blue: 0.965, alpha: 1)
let encre = CGColor(srgbRed: 0.45, green: 0.08, blue: 0.27, alpha: 1)
ctx.setFillColor(fond)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ctx.interpolationQuality = .high

func ecrire(_ texte: String, taille: CGFloat, gras: Bool, x: CGFloat, y: CGFloat) {
    let police = CTFontCreateWithName((gras ? "Helvetica-Bold" : "Helvetica") as CFString, taille, nil)
    let attributs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(rawValue: kCTFontAttributeName as String): police,
        NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): encre,
    ]
    let ligne = CTLineCreateWithAttributedString(NSAttributedString(string: texte, attributes: attributs))
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(ligne, ctx)
}

// Repère de CoreGraphics : origine en bas à gauche.
ecrire(titre, taille: 30, gras: true, x: marge, y: H - 52)
for (i, element) in images.enumerated() {
    let colonne = CGFloat(i % colonnes), ligne = CGFloat(i / colonnes)
    let x = marge + colonne * (largeur + marge)
    let haut = H - entete - ligne * (hauteur + legende + marge)
    let cadre = CGRect(x: x, y: haut - hauteur, width: largeur, height: hauteur)
    let arrondi = CGPath(roundedRect: cadre, cornerWidth: 22, cornerHeight: 22, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: CGColor(gray: 0, alpha: 0.2))
    ctx.addPath(arrondi)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(arrondi)
    ctx.clip()
    ctx.draw(element.image, in: cadre)
    ctx.restoreGState()
    ecrire(element.nom, taille: 18, gras: false, x: x + 4, y: haut - hauteur - 28)
}

guard let planche = ctx.makeImage(),
      let destination = CGImageDestinationCreateWithURL(sortie as CFURL, "public.png" as CFString, 1, nil)
else { echec("écriture impossible : \(sortie.path)") }
CGImageDestinationAddImage(destination, planche, nil)
guard CGImageDestinationFinalize(destination) else { echec("écriture impossible : \(sortie.path)") }
print("planche : \(images.count) captures, \(Int(W))×\(Int(H)) px")
