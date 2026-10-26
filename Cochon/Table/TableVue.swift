import CochonMoteur
import CochonTable
import SwiftUI

/// La table de jeu, d'après la maquette 1 « Fête foraine ».
struct TableVue: View {
    let reglages: Reglages
    let quitter: () -> Void
    /// Mode démo : ouvrir le menu de la partie dès l'arrivée.
    let menuAuDepart: Bool

    @State private var modele: TableModele
    @State private var menuOuvert = false
    @State private var reglesOuvertes = false
    @Environment(\.accessibilityReduceMotion) private var reduire

    init(reglages: Reglages, scene: SceneDemo? = nil, quitter: @escaping () -> Void) {
        self.reglages = reglages
        self.quitter = quitter
        menuAuDepart = scene?.ecran == .menu
        _modele = State(initialValue: scene.map { TableModele(reglages: reglages, scene: $0) }
                            ?? TableModele(reglages: reglages))
    }

    var body: some View {
        ZStack {
            FondFoire()
            GeometryReader { geo in
                let d = Disposition(taille: geo.size, moi: modele.moi, nombreJoueurs: modele.vue.nombreJoueurs)
                ZStack {
                    Projecteur(modele: modele, d: d)
                    FlechesTournantes(actives: modele.distributionFaite && modele.vue.phase != .ouverture
                                      && modele.vue.phase != .terminee)
                        .frame(width: d.rayonFleches * 2, height: d.rayonFleches * 2)
                        .position(d.centreTable)
                    legendesDesTas(d)
                    etiquettes(d)
                    cartes(d)
                    indicePioche(d)
                    zoneCentrale(d)
                    BoutonCochon(actif: modele.commandes.cochonActif, diametre: d.diametreCochon) {
                        modele.geste(.cochon)
                    }
                    .position(d.boutonCochon)
                    haut(d)
                    CalqueAnnonces(modele: modele, d: d)
                }
            }
            if modele.resultatsVisibles {
                ResultatsVue(vue: modele.vue, rejouer: rejouer, accueil: quitter)
                    .transition(.apparition(echelle: 0.96, reduire: reduire))
            }
        }
        .sensoryFeedback(trigger: modele.impulsion) { _, nouvelle in
            nouvelle.map { retour($0.type) }
        }
        .onAppear {
            modele.rythme.reduire = reduire
            modele.demarrer()
            if menuAuDepart { menuOuvert = true }
        }
        .onDisappear { modele.arreter() }
        .onChange(of: reduire) { _, valeur in modele.rythme.reduire = valeur }
        .sheet(isPresented: $menuOuvert) {
            MenuPartie(reprendre: { menuOuvert = false },
                       regles: { menuOuvert = false; reglesOuvertes = true },
                       nouvellePartie: { menuOuvert = false; rejouer() },
                       accueil: { menuOuvert = false; quitter() })
                .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $reglesOuvertes) { ReglesVue() }
    }

    private func rejouer() {
        modele.arreter()
        let nouveau = TableModele(reglages: reglages)
        nouveau.rythme.reduire = reduire
        modele = nouveau
        nouveau.demarrer()
    }

    // MARK: - Haut : menu et bandeau

    private func haut(_ d: Disposition) -> some View {
        let b = Textes.banniere(modele.vue, tour: modele.compteur.tour)
        return ZStack {
            Button { menuOuvert = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Palette.jauneIcone)
                    .frame(width: 46 * d.echelle, height: 42 * d.echelle)
            }
            .buttonStyle(.bonbonJaune)
            .accessibilityLabel("Menu")
            .position(d.boutonMenu)

            Banniere(banniere: b, appels: modele.appelsATour)
                .frame(width: 262 * d.echelle, height: 46 * d.echelle)
                .position(d.banniere)
        }
    }

    // MARK: - Tas et étiquettes

    private func legendesDesTas(_ d: Disposition) -> some View {
        ZStack {
            Pastille(texte: "Pioche", taille: 12).position(d.m(139, 430))
            Pastille(texte: "Défausse", taille: 12).position(d.m(251, 430))
        }
        .accessibilityHidden(true)
    }

    private func etiquettes(_ d: Disposition) -> some View {
        ForEach(0..<modele.vue.nombreJoueurs, id: \.self) { j in
            let place = d.place(j)
            EtiquetteJoueur(nom: Textes.nom(j, moi: modele.moi),
                            cartes: modele.plateau.mains[j].count,
                            estMoi: j == modele.moi,
                            actif: modele.distributionFaite && modele.vue.actif == j
                                && modele.vue.phase != .ouverture && modele.vue.phase != .terminee,
                            score: modele.vue.scores?[j])
                .position(d.etiquette(place))
        }
    }

    // MARK: - Cartes

    private func cartes(_ d: Disposition) -> some View {
        let c = modele.commandes
        // Calque à part : les `zIndex` des cartes ne s'appliquent qu'entre
        // cartes, jamais au-dessus du bandeau, des boutons ou des annonces.
        return ZStack { ForEach(modele.jetons) { jeton in
            let taille = tailleMain(jeton.lieu)
            let pose = d.pose(jeton.lieu, tailleMain: taille, jeton: jeton.id)
            let mienne = estMienne(jeton.lieu)
            CarteRetournable(face: jeton.face, montree: jeton.montree, taille: pose.taille)
                .overlay {
                    if mienne {
                        RoundedRectangle(cornerRadius: max(5, pose.taille.width * 0.13), style: .continuous)
                            .strokeBorder(Palette.fleche, lineWidth: 3)
                            .padding(-3)
                            .shadow(color: Palette.fleche.opacity(c.mainTouchable ? 0.9 : 0), radius: 8)
                    }
                }
                .overlay(alignment: .top) {
                    if mienne && jeton.face != nil && !jeton.montree { BadgeVue().offset(y: -12) }
                }
                .rotation3DEffect(.degrees(jeton.incline ? 52 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .scaleEffect(jeton.souleve ? 1.12 : 1)
                .offset(y: jeton.souleve ? -16 * d.echelle : 0)
                .rotationEffect(.degrees(jeton.souleve ? 0 : pose.rotation))
                .shadow(color: Palette.ombreCarte.opacity(jeton.souleve ? 0.35 : 0), radius: 12, y: 10)
                .overlay {
                    if case .tenue(let j) = jeton.lieu, j == modele.moi, jeton.montree {
                        HaloTenue(taille: pose.taille)
                    }
                }
                // Zone de toucher posée AVANT `.position` (qui occupe tout l'écran).
                .contentShape(Rectangle().inset(by: -6))
                .onTapGesture { modele.toucher(jeton) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(etiquetteAccessible(jeton))
                .accessibilityAddTraits(touchable(jeton, c) ? .isButton : [])
                .accessibilityAction { modele.toucher(jeton) }
                .accessibilityHidden(cachee(jeton))
                .position(pose.centre)
                .zIndex(jeton.z)
        } }
    }

    private func estMienne(_ lieu: Lieu) -> Bool {
        if case .main(let j, _) = lieu { return j == modele.moi }
        return false
    }

    private func tailleMain(_ lieu: Lieu) -> Int {
        if case .main(let j, _) = lieu { return modele.plateau.mains[j].count }
        return 4
    }

    private func touchable(_ j: JetonAffiche, _ c: Commandes) -> Bool {
        switch j.lieu {
        case .pioche: return c.piochePossible
        case .defausse: return c.defaussePrenable || c.defausserVisible
        case .main(let p, _): return p == modele.moi ? c.mainTouchable : c.adversesTouchables
        case .tenue: return false
        }
    }

    /// Une seule carte de chaque tas est lue par VoiceOver.
    private func cachee(_ j: JetonAffiche) -> Bool {
        switch j.lieu {
        case .pioche(let p): return p > 0
        case .defausse(let p, _): return p > 0
        default: return false
        }
    }

    private func etiquetteAccessible(_ j: JetonAffiche) -> String {
        switch j.lieu {
        case .pioche: return "Pioche, \(modele.plateau.pioche.count) cartes"
        case .defausse: return "Défausse : \(Textes.accessibilite(j.face))"
        case .tenue(let p):
            return p == modele.moi ? "Ta carte piochée : \(Textes.accessibilite(j.montree ? j.face : nil))"
                                   : "Carte tenue par \(Textes.nom(p, moi: modele.moi))"
        case .main(let p, let i):
            let qui = p == modele.moi ? "Ta carte \(i + 1)" : "\(Textes.nom(p, moi: modele.moi)), carte \(i + 1)"
            return "\(qui) : \(j.montree ? Textes.accessibilite(j.face) : (j.face != nil && p == modele.moi ? "déjà vue" : "cachée"))"
        }
    }

    // MARK: - Indice « tu peux piocher »

    @ViewBuilder
    private func indicePioche(_ d: Disposition) -> some View {
        if modele.commandes.piochePossible {
            IndiceRebond()
                .position(x: d.pioche.x, y: d.pioche.y - d.carteTable.height / 2 - 24 * d.echelle)
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Zone centrale : légende, actions

    @ViewBuilder
    private func zoneCentrale(_ d: Disposition) -> some View {
        let v = modele.vue
        let c = modele.commandes
        if v.phase == .ouverture && modele.distributionFaite {
            PanneauOuverture(restants: v.regardsOuvertureRestants)
                .position(d.m(195, 560))
                .transition(.opacity)
        } else if let texte = Textes.legendeTenue(v) ?? Textes.consigne(v, valetMien: modele.valetMien,
                                                                           attenteRemplacement: modele.attenteRemplacement),
                  !modele.occupe || Textes.legendeTenue(v) != nil {
            Pastille(texte: texte)
                .frame(maxWidth: 330 * d.echelle)
                .position(d.legende)
                .transition(.opacity)
        }
        if c.remplacerVisible {
            Button { modele.geste(.boutonRemplacer) } label: {
                EtiquetteAction(icone: "arrow.down", texte: "Remplacer", taille: d.tailleBoutonAction)
            }
            .buttonStyle(.bonbonVert)
            .position(d.boutonRemplacer)
            .transition(.apparition(echelle: 0.95, reduire: reduire))
        }
        if c.defausserVisible {
            Button { modele.geste(.boutonDefausser) } label: {
                EtiquetteAction(icone: "arrow.up", texte: "Défausser", taille: d.tailleBoutonAction)
            }
            .buttonStyle(.bonbonBleu)
            .position(d.boutonDefausser)
            .transition(.apparition(echelle: 0.95, reduire: reduire))
        }
        if c.finDuTourVisible {
            Button { modele.geste(.finDuTour) } label: {
                EtiquetteAction(icone: "checkmark", texte: "Fin du tour",
                                taille: CGSize(width: 160 * d.echelle, height: d.tailleBoutonAction.height))
            }
            .buttonStyle(.bonbonBleu)
            .position(d.m(195, 598))
            .transition(.apparition(echelle: 0.95, reduire: reduire))
        }
    }

    private func retour(_ h: Haptique) -> SensoryFeedback {
        switch h {
        case .selection: return .selection
        case .leger: return .impact(weight: .light)
        case .moyen: return .impact(weight: .medium)
        case .fort: return .impact(weight: .heavy, intensity: 1)
        case .succes: return .success
        case .erreur: return .error
        case .avertissement: return .warning
        }
    }
}

// MARK: - Morceaux de la table

/// Bandeau du haut : « À toi ! » turquoise, ou « ORDI 2 joue » framboise,
/// mascotte à cheval sur le bord gauche. Rebondit à chaque « À toi ! ».
struct Banniere: View {
    let banniere: Textes.Banniere
    let appels: Int
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        let face = banniere.aMoi ? Palette.turquoise : Palette.framboise
        let ombre = banniere.aMoi ? Palette.turquoiseOmbre : Palette.framboiseTexte
        let socle = banniere.aMoi ? Palette.turquoiseSocle : Palette.framboiseSocle
        let forme = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 8) {
            Text(banniere.titre)
                .font(Police.titre(21))
                .foregroundStyle(.white)
                .shadow(color: socle, radius: 0, x: 0, y: 2)
                .contentTransition(.opacity)
            Spacer(minLength: 4)
            if let detail = banniere.detail {
                Text(detail)
                    .font(Police.texte(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.white.opacity(0.22)))
            }
        }
        .padding(.leading, 58)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            forme.fill(ombre).overlay(alignment: .top) { forme.fill(face).padding(.bottom, 5) }
        }
        .background { forme.fill(socle).offset(y: 4).shadow(color: socle.opacity(0.35), radius: 6, y: 6) }
        .overlay(alignment: .topLeading) {
            Mascotte(taille: 64).rotationEffect(.degrees(-10)).offset(x: -6, y: -18)
        }
        .animation(Courbe.sortie(0.25), value: banniere)
        .keyframeAnimator(initialValue: 1.0, trigger: appels) { contenu, echelle in
            contenu.scaleEffect(reduire ? 1 : echelle)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.06, duration: 0.18, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Étiquette d'un joueur : nombre de cartes + nom ; pastille turquoise
/// qui palpite sur le joueur dont c'est le tour.
struct EtiquetteJoueur: View {
    let nom: String
    let cartes: Int
    let estMoi: Bool
    let actif: Bool
    var score: Int?
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        HStack(spacing: 6) {
            if estMoi {
                if actif { pastille }
                Text(nom).font(Police.etiquette(13))
                compteur(Palette.turquoise)
            } else {
                compteur(Palette.rose)
                Text(nom).font(Police.etiquette(13))
                if actif { pastille }
            }
            if let score {
                Text("\(score) pts").font(Police.titre(14)).foregroundStyle(Palette.framboise)
            }
        }
        .foregroundStyle(Palette.framboiseTexte)
        .padding(.leading, estMoi ? 10 : 3)
        .padding(.trailing, estMoi ? 4 : 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white))
        .background(Capsule().fill(Palette.framboiseTexte).offset(y: 3))
        .scaleEffect(actif && !reduire ? 1.06 : 1)
        .animation(Courbe.sortie(0.25), value: actif)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nom), \(cartes) carte\(cartes > 1 ? "s" : "")\(actif ? ", joue" : "")")
    }

    private func compteur(_ couleur: Color) -> some View {
        Text("\(cartes)")
            .font(Police.titre(15))
            .foregroundStyle(.white)
            .frame(minWidth: 24, minHeight: 24)
            .background(Circle().fill(couleur))
            .contentTransition(.numericText())
            .animation(Courbe.sortie(0.2), value: cartes)
    }

    private var pastille: some View {
        Circle()
            .fill(Palette.turquoise)
            .frame(width: 12, height: 12)
            .background {
                Circle().fill(Palette.turquoise.opacity(0.35))
                    .phaseAnimator([false, true]) { halo, grand in
                        halo.scaleEffect(reduire ? 1.6 : (grand ? 2.1 : 1.4)).opacity(reduire ? 1 : (grand ? 0.2 : 1))
                    } animation: { _ in .easeInOut(duration: 0.8) }
            }
    }
}

/// Repère du joueur actif : un halo doux qui glisse de place en place,
/// sous l'étiquette de celui qui joue.
struct Projecteur: View {
    let modele: TableModele
    let d: Disposition
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        let v = modele.vue
        let visible = modele.distributionFaite && v.phase != .ouverture && v.phase != .terminee
        let centre = d.etiquette(d.place(v.actif))
        Ellipse()
            .fill(RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: 80 * d.echelle))
            .frame(width: 180 * d.echelle, height: 110 * d.echelle)
            .position(centre)
            // Réduire les animations : le halo ne glisse pas, il change de
            // place d'un coup (le fondu d'apparition reste).
            .animation(reduire ? nil : Courbe.vol(0.5), value: v.actif)
            .opacity(visible ? 1 : 0)
            .animation(Courbe.sortie(0.3), value: visible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Les deux flèches courbes de la maquette autour de la pioche et de la
/// défausse, qui tournent lentement dans le sens du jeu (comme UNO).
struct FlechesTournantes: View {
    let actives: Bool
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !actives || reduire)) { contexte in
            let t = contexte.date.timeIntervalSinceReferenceDate
            Fleches()
                .rotationEffect(.degrees(actives && !reduire ? (t * 45).truncatingRemainder(dividingBy: 360) : 0))
        }
        .opacity(actives ? 1 : 0.35)
        .animation(Courbe.sortie(0.3), value: actives)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Deux arcs de 90° (rayon 96 sur 240) terminés par une pointe.
struct Fleches: View {
    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 240
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = 96 * k
            let style = StrokeStyle(lineWidth: 11 * k, lineCap: .round)
            for (debut, fin) in [(211.4, 301.2), (31.4, 121.2)] {
                var arc = Path()
                arc.addArc(center: c, radius: r, startAngle: .degrees(debut), endAngle: .degrees(fin), clockwise: false)
                ctx.stroke(arc, with: .color(Palette.fleche), style: style)
                func point(_ a: Double, _ rr: CGFloat) -> CGPoint {
                    CGPoint(x: c.x + rr * CGFloat(cos(a * .pi / 180)), y: c.y + rr * CGFloat(sin(a * .pi / 180)))
                }
                var pointe = Path()
                pointe.move(to: point(fin + 10, r))
                pointe.addLine(to: point(fin - 1, r - 15 * k))
                pointe.addLine(to: point(fin - 1, r + 15 * k))
                pointe.closeSubpath()
                ctx.fill(pointe, with: .color(Palette.fleche))
            }
        }
    }
}

/// Triangle jaune qui rebondit au-dessus de la pioche quand on peut piocher.
struct IndiceRebond: View {
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(Palette.fleche)
            .shadow(color: Palette.framboiseSocle, radius: 0, x: 0, y: 3)
            .phaseAnimator([false, true]) { fleche, haut in
                fleche.offset(y: reduire ? 0 : (haut ? -10 : 0))
            } animation: { haut in
                haut ? .spring(duration: 0.35, bounce: 0) : .spring(duration: 0.45, bounce: 0.55)
            }
    }
}

/// Halo de la carte que je viens de piocher (blanc 55 % + lueur jaune).
struct HaloTenue: View {
    let taille: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: max(5, taille.width * 0.13) + 6, style: .continuous)
            .strokeBorder(.white.opacity(0.55), lineWidth: 6)
            .padding(-6)
            .shadow(color: Color(hex: 0xFFF696, opacite: 0.9), radius: 24)
            .allowsHitTesting(false)
    }
}

/// Badge « vue » au-dessus d'une de mes cartes déjà regardée.
struct BadgeVue: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "eye").font(.system(size: 11, weight: .bold))
            Text("vue").font(Police.etiquette(12))
        }
        .foregroundStyle(Palette.fleche)
        .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 2)
        .background(Capsule().fill(Palette.encre))
        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 2)
        .accessibilityHidden(true)
    }
}

/// Libellé des gros boutons d'action : icône au-dessus du texte.
struct EtiquetteAction: View {
    let icone: String
    let texte: String
    let taille: CGSize

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icone).font(.system(size: 20, weight: .heavy))
            Text(texte).font(Police.titre(18))
        }
        .frame(width: taille.width, height: taille.height)
    }
}

/// Le gros bouton rond COCHON! (maquette : 100 pt, penché de -8°, anneaux
/// blanc et jaune). Éteint hors de propos : désaturé et disque assombri,
/// texte blanc plein (contraste ≥ 3:1, sans opacité qui laisserait passer
/// le fond) ; quand il s'allume, il frétille une fois.
struct BoutonCochon: View {
    let actif: Bool
    let diametre: CGFloat
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduire

    var body: some View {
        Button(action: action) {
            Text("COCHON!")
                .font(Police.titre(22 * diametre / 100))
                .foregroundStyle(.white)
                .shadow(color: Palette.framboiseSocle, radius: 0, x: 0, y: 3)
                .frame(width: diametre, height: diametre)
        }
        .buttonStyle(StyleCochon(diametre: diametre, actif: actif))
        .rotationEffect(.degrees(-8))
        .saturation(actif ? 1 : 0.35)
        .disabled(!actif)
        .keyframeAnimator(initialValue: 0.0, trigger: actif) { bouton, angle in
            bouton.rotationEffect(.degrees(actif && !reduire ? angle : 0))
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-6, duration: 0.08)
                CubicKeyframe(6, duration: 0.12)
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(0, duration: 0.12)
            }
        }
        .accessibilityLabel("Annoncer COCHON!")
        .accessibilityHint(actif ? "Dernier tour pour les autres, puis on compte." : "Possible à la fin de ton tour.")
    }
}

private struct StyleCochon: ButtonStyle {
    let diametre: CGFloat
    let actif: Bool

    func makeBody(configuration: Configuration) -> some View {
        let enfonce = configuration.isPressed
        configuration.label
            .background {
                Circle()
                    .fill(RadialGradient(colors: [Palette.cochonClair, Palette.cochonRouge],
                                         center: UnitPoint(x: 0.4, y: 0.3), startRadius: 0, endRadius: diametre * 0.6))
                    .overlay(Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.4), .clear, .clear, Palette.cochonOmbre],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 6))
                    // Éteint : seul le disque s'assombrit, le texte reste blanc.
                    .brightness(actif ? 0 : -0.2)
            }
            .offset(y: enfonce ? 4 : 0)
            .background { Circle().fill(Palette.framboiseSocle).offset(y: 6) }
            .padding(5)
            .background(Circle().fill(.white))
            .padding(4)
            .background(Circle().fill(Palette.jaune))
            .shadow(color: Palette.ombreCarte.opacity(0.45), radius: 10, x: 0, y: 12)
            .scaleEffect(enfonce ? 0.96 : 1)
            .animation(Courbe.sortie(0.14), value: enfonce)
    }
}

/// Le petit écran du départ : regarder 2 de ses cartes.
struct PanneauOuverture: View {
    let restants: Int

    var body: some View {
        HStack(spacing: 12) {
            Mascotte(taille: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(restants > 0 ? "Regarde 2 de tes cartes" : "C'est noté !")
                    .font(Police.titre(19))
                    .foregroundStyle(Palette.framboise)
                Text(restants > 0 ? "Touche-les une par une et retiens-les : elles restent cachées toute la manche."
                                  : "Les ordis regardent les leurs…")
                    .font(Police.texte(13))
                    .foregroundStyle(Palette.prune)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .fill(i < 2 - restants ? Palette.turquoise : Palette.framboise.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: 330)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.framboiseTexte).offset(y: 4))
        .animation(Courbe.sortie(0.25), value: restants)
        .accessibilityElement(children: .combine)
    }
}
