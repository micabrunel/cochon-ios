import CochonIA
import CochonTable
import SwiftUI

@main
struct CochonApp: App {
    /// Mode démo : `-ecran <nom> [-graine <n>]` (scripts/captures-ecrans.sh).
    private let demo = Demo.lancement(arguments: ProcessInfo.processInfo.arguments)
    /// Mode démo : la table figée, calculée une seule fois au lancement
    /// (jusqu'à 300 parties essayées), jamais à chaque ré-init d'une vue.
    private let scene: SceneDemo?

    init() {
        let lancement = demo
        scene = lancement.ecran.flatMap { Demo.scene($0, graine: lancement.graine) }
        // Captures identiques d'une fois sur l'autre : réglages par défaut,
        // quels que soient ceux restés dans le simulateur. Seulement quand
        // l'app est lancée avec `-ecran` (jamais par un joueur).
        if demo.actif {
            let reglages = Reglages(nombreJoueurs: Demo.nombreJoueurs)
            let d = UserDefaults.standard
            d.set(reglages.nombreJoueurs, forKey: "joueurs")
            d.set(reglages.vitesse.rawValue, forKey: "vitesse")
            d.set(reglages.niveau.rawValue, forKey: "niveau")
            d.set(reglages.montrerConnues, forKey: "montrerConnues")
        }
    }

    var body: some Scene {
        WindowGroup {
            RacineVue(demo: demo, scene: scene)
        }
    }
}

/// Accueil ↔ partie, avec les réglages gardés entre deux lancements.
struct RacineVue: View {
    let demo: LancementDemo
    /// Mode démo mal lancé : on l'écrit en clair, la capture le montrera.
    private let problemeDemo: String?

    @AppStorage("joueurs") private var nombreJoueurs = 4
    @AppStorage("vitesse") private var vitesse: Vitesse = .normale
    @AppStorage("niveau") private var niveau: NiveauIA = .malin
    @AppStorage("montrerConnues") private var montrerConnues = false

    @State private var enPartie: Bool
    @State private var reglesOuvertes = false
    @State private var parametresOuverts = false
    /// Mode démo : la table figée à ouvrir (une seule fois).
    @State private var scene: SceneDemo?

    init(demo: LancementDemo = LancementDemo(graine: Demo.graineParDefaut), scene: SceneDemo? = nil) {
        self.demo = demo
        _scene = State(initialValue: scene)
        _enPartie = State(initialValue: scene != nil)
        if let nom = demo.nomInconnu {
            let noms = EcranDemo.allCases.map(\.rawValue).joined(separator: ", ")
            problemeDemo = "Écran démo inconnu : « \(nom) ».\nÉcrans : \(noms)."
        } else if let ecran = demo.ecran, ecran.surLaTable, scene == nil {
            problemeDemo = "Écran démo « \(ecran.rawValue) » introuvable avec la graine \(demo.graine)."
        } else {
            problemeDemo = nil
        }
    }

    private var reglages: Reglages {
        Reglages(nombreJoueurs: min(max(nombreJoueurs, 2), 4), vitesse: vitesse, niveau: niveau,
                 montrerConnues: montrerConnues)
    }

    var body: some View {
        ZStack {
            if let problemeDemo {
                ErreurDemoVue(texte: problemeDemo)
            } else if enPartie {
                TableVue(reglages: reglages, scene: scene) {
                    scene = nil
                    withAnimation(.easeOut(duration: 0.25)) { enPartie = false }
                }
                .transition(.opacity)
            } else {
                AccueilVue(jouer: { withAnimation(.easeOut(duration: 0.25)) { enPartie = true } },
                           regles: { reglesOuvertes = true },
                           parametres: { parametresOuverts = true },
                           resume: resume)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $reglesOuvertes) { ReglesVue() }
        .sheet(isPresented: $parametresOuverts) {
            ParametresVue(nombreJoueurs: $nombreJoueurs, vitesse: $vitesse, niveau: $niveau,
                          montrerConnues: $montrerConnues) { parametresOuverts = false }
            // Hauteur : celle du contenu, posée par la vue elle-même (FeuilleAjustee).
        }
        .onAppear {
            if demo.ecran == .regles { reglesOuvertes = true }
            if demo.ecran == .parametres { parametresOuverts = true }
        }
    }

    private var resume: String {
        let ordis = nombreJoueurs - 1
        let niveauTexte = niveau == .facile ? "facile" : "malin"
        return "\(ordis) ordi\(ordis > 1 ? "s" : ""), niveau \(niveauTexte), vitesse \(vitesse.nom.lowercased())"
    }
}

/// Erreur du mode démo, en gros, sur fond rouge.
struct ErreurDemoVue: View {
    let texte: String

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()
            Text(texte)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(32)
        }
    }
}
