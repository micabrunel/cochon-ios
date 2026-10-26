import SwiftUI

/// Feuille du bas qui prend la hauteur de son contenu : en-tête fixe en
/// haut, le reste dans un défilement.
///
/// La hauteur (`.presentationDetents`) est mesurée sur le contenu réel,
/// donc elle suit le modèle d'iPhone et la taille du texte (Dynamic Type).
/// Quand le contenu dépasse l'écran (très grand texte), le système plafonne
/// la feuille à la hauteur maximale et le contenu défile sous l'en-tête,
/// qui reste visible. Rien n'est jamais coupé en haut.
struct FeuilleAjustee<Entete: View, Contenu: View>: View {
    /// Hauteur utilisée avant la première mesure (un seul passage de mise en page).
    let hauteurEstimee: CGFloat
    @ViewBuilder let entete: () -> Entete
    @ViewBuilder let contenu: () -> Contenu

    @State private var hauteurEntete: CGFloat?
    @State private var hauteurContenu: CGFloat?
    /// Écart entre la hauteur demandée au détent et la place réellement
    /// donnée à la vue (zone de l'indicateur d'accueil, feuille flottante…).
    /// Il dépend de l'iPhone et de la version d'iOS : on le mesure au lieu
    /// de le deviner.
    @State private var decalage: CGFloat?

    init(hauteurEstimee: CGFloat, @ViewBuilder entete: @escaping () -> Entete,
         @ViewBuilder contenu: @escaping () -> Contenu) {
        self.hauteurEstimee = hauteurEstimee
        self.entete = entete
        self.contenu = contenu
    }

    private var hauteur: CGFloat {
        guard let hauteurEntete, let hauteurContenu, let decalage else { return hauteurEstimee }
        return (hauteurEntete + hauteurContenu + decalage).rounded(.up)
    }

    var body: some View {
        let demandee = hauteur
        VStack(spacing: 0) {
            entete()
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hauteurEntete = $0 }
            ScrollView {
                contenu()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hauteurContenu = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { recue in
            // On garde le plus petit écart observé : quand la feuille est
            // plafonnée par l'écran (ou en cours d'animation), la place reçue
            // est plus petite que demandée, l'écart calculé est trop grand ;
            // il ne doit pas faire grandir la feuille à la mesure suivante.
            let ecart = demandee - recue
            decalage = min(decalage ?? ecart, ecart)
        }
        .presentationDetents([.height(demandee)])
    }
}
