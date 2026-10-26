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
    @State private var margeBas: CGFloat = 0

    init(hauteurEstimee: CGFloat, @ViewBuilder entete: @escaping () -> Entete,
         @ViewBuilder contenu: @escaping () -> Contenu) {
        self.hauteurEstimee = hauteurEstimee
        self.entete = entete
        self.contenu = contenu
    }

    /// Hauteur de la feuille : en-tête + contenu + zone de l'indicateur
    /// d'accueil (comprise dans la hauteur d'un détent `.height`).
    private var hauteur: CGFloat {
        guard let hauteurEntete, let hauteurContenu else { return hauteurEstimee }
        return (hauteurEntete + hauteurContenu + margeBas).rounded(.up)
    }

    var body: some View {
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
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { margeBas = $0 }
        .presentationDetents([.height(hauteur)])
    }
}
