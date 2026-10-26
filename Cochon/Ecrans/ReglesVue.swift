import SwiftUI

/// Les règles, pour le joueur (source : docs/REGLES.md).
struct ReglesVue: View {
    @Environment(\.dismiss) var fermer

    private let sections: [(String, String)] = [
        ("Le but", "Finir la manche avec le plus petit total. As = 1, 2 à 10 = leur valeur, Valet et Dame = 10, Roi noir = 0, Roi rouge = 30."),
        ("Au départ", "Tu as 4 cartes cachées. Regardes-en 2, une par une, et retiens-les : elles restent cachées toute la manche."),
        ("À ton tour", "Pioche une carte, ou prends celle de la défausse. Puis remplace une de tes cartes (l'ancienne part à la défausse), ou défausse la carte piochée. Une carte prise à la défausse doit remplacer une carte."),
        ("Valet et Dame", "Défaussés tout droit depuis la pioche, ils donnent un pouvoir. Valet : échange à l'aveugle une de tes cartes avec celle d'un ordi. Dame : regarde une de tes cartes."),
        ("Réflexe", "Après ton coup, si une de tes cartes a le même rang que le dessus de la défausse, touche-la pour t'en débarrasser. Si tu te trompes : une carte de pénalité."),
        ("COCHON!", "À la fin de ton tour, si ta main te semble basse, annonce COCHON!. Les autres jouent une dernière fois, puis tout le monde montre ses cartes et on compte."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections, id: \.0) { titre, texte in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(titre).font(Police.titre(20)).foregroundStyle(Palette.framboise)
                                .accessibilityAddTraits(.isHeader)
                            Text(texte).font(Police.texte(16)).foregroundStyle(Palette.prune)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(hex: 0xE2B6C8)).offset(y: 3))
                    }
                }
                .padding(20)
            }
            .background(Palette.carteFondBas.ignoresSafeArea())
            .navigationTitle("Règles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { fermer() } }
            }
        }
    }
}
