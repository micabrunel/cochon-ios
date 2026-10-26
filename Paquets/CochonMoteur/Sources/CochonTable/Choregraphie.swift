// Chorégraphie : traduit les événements publics du moteur en étapes
// d'animation (mouvements des cartes, durée, retour haptique, annonce).
// Référence de mouvement : UNO (docs/DESIGN.md, « Mouvement »).
//
// Les seules faces privées utilisées sont celles du joueur, lues dans SA
// vue après le coup (carte qu'il vient de piocher, carte qu'il regarde) :
// une carte d'ordinateur reste cachée tant que le moteur ne l'a pas rendue
// publique.

import CochonMoteur

public enum Haptique: String, Equatable, Sendable {
    case selection
    case leger
    case moyen
    case fort
    case succes
    case erreur
    case avertissement
}

/// Surimpression éphémère au-dessus de la table.
public enum Annonce: Equatable, Sendable {
    case aToi
    case valet(joueur: Int)
    case dame(joueur: Int)
    case pouvoirPerdu(joueur: Int)
    case reflexeReussi(joueur: Int)
    case reflexeRate(joueur: Int)
    /// « +1 » flottant près de l'étiquette du joueur pénalisé.
    case plusUn(joueur: Int)
    /// Grande annonce COCHON! avec la mascotte.
    case cochon(joueur: Int, toursRestants: Int)
}

public struct Etape: Equatable, Sendable {
    public var mouvements: [Mouvement]
    public var style: StyleAnimation
    /// Attente après le lancement de l'étape, avant la suivante (secondes,
    /// vitesse comprise). Toujours au moins la durée de l'animation.
    public var attente: Double
    public var haptique: Haptique?
    public var annonce: Annonce?

    public init(_ mouvements: [Mouvement], _ style: StyleAnimation, attente: Double,
                haptique: Haptique? = nil, annonce: Annonce? = nil) {
        self.mouvements = mouvements
        self.style = style
        self.attente = attente
        self.haptique = haptique
        self.annonce = annonce
    }
}

public enum Choregraphie {

    /// Distribution animée depuis la pioche, carte par carte, dans l'ordre
    /// du moteur (une carte à chacun, quatre tours), puis la première
    /// carte retournée sur la défausse.
    public static func distribution(nombreJoueurs n: Int, premiere: Carte, rythme: Rythme) -> [Etape] {
        var etapes: [Etape] = []
        for _ in 0..<ConfigPartie.cartesParJoueur {
            for j in 0..<n {
                etapes.append(Etape([.distribuer(joueur: j)], .distribution, attente: rythme.intervalleDistribution))
            }
        }
        etapes.append(Etape([.retournerSurDefausse(premiere)], .vol, attente: rythme.duree(0.5), haptique: .leger))
        return etapes
    }

    /// Étapes d'un coup, à partir de ses événements et de la vue du joueur
    /// juste après ce coup.
    public static func etapes(pour evenements: [Evenement], moi: Int, vueApres vue: VueJoueur, rythme r: Rythme) -> [Etape] {
        var e: [Etape] = []
        func maFace(_ emp: Int) -> Carte? {
            vue.mains[moi].indices.contains(emp) ? vue.mains[moi][emp] : nil
        }

        for ev in evenements {
            switch ev {
            case .regardOuverture(let j, let emp):
                if j == moi {
                    e += regard(joueur: j, emplacement: emp, face: maFace(emp), tenir: 1.5, r)
                } else {
                    e += coupDOeil(joueur: j, emplacement: emp, tenir: 0.35, r)
                }

            case .debutDuJeu(let premier):
                e.append(Etape([], .immediat, attente: r.duree(0.4),
                               haptique: premier == moi ? .selection : nil,
                               annonce: premier == moi ? .aToi : nil))

            case .pioche(let j, let source, let visible):
                let face: Carte? = (j == moi && source == .pioche) ? vue.cartePiochee : visible
                e.append(Etape([.prendre(joueur: j, source: source, face: face)], .vol,
                               attente: r.duree(0.45), haptique: j == moi ? .leger : nil))
                if j == moi && source == .pioche {
                    e.append(Etape([.montrerTenue(true)], .retournement, attente: r.duree(0.4)))
                }

            case .remplacement(let j, let emp, let ancienne):
                e.append(Etape([.soulever(joueur: j, emplacement: emp, true)], .soulevement, attente: r.duree(0.2)))
                e.append(Etape([.remplacer(joueur: j, emplacement: emp, ancienne: ancienne)], .vol,
                               attente: r.duree(0.5), haptique: j == moi ? .moyen : nil))

            case .defausse(let j, let carte):
                var annonce: Annonce?
                if vue.actif == j, carte.rang == .valet, vue.phase == .pouvoirValet { annonce = .valet(joueur: j) }
                if vue.actif == j, carte.rang == .dame, vue.phase == .pouvoirDame { annonce = .dame(joueur: j) }
                e.append(Etape([.defausserTenue(carte)], .vol, attente: r.duree(annonce == nil ? 0.45 : 0.9),
                               haptique: j == moi ? .leger : nil, annonce: annonce))

            case .pouvoirSaute(let j, _):
                e.append(Etape([], .immediat, attente: r.duree(0.8), annonce: .pouvoirPerdu(joueur: j)))

            case .echangeValet(let j, let emp, let adv, let sien):
                e.append(Etape([.soulever(joueur: j, emplacement: emp, true),
                                .soulever(joueur: adv, emplacement: sien, true)],
                               .soulevement, attente: r.duree(0.25)))
                e.append(Etape([.echanger(joueur: j, emplacement: emp, adversaire: adv, sonEmplacement: sien)],
                               .croisement, attente: r.duree(0.7), haptique: .moyen))
                e.append(Etape([.soulever(joueur: j, emplacement: emp, false),
                                .soulever(joueur: adv, emplacement: sien, false)],
                               .soulevement, attente: r.duree(0.2)))

            case .regardDame(let j, let emp):
                if j == moi {
                    e += regard(joueur: j, emplacement: emp, face: maFace(emp), tenir: 1.6, r)
                } else {
                    e += coupDOeil(joueur: j, emplacement: emp, tenir: 0.9, r)
                }

            case .reflexeReussi(let j, let emp, let carte):
                e.append(Etape([.soulever(joueur: j, emplacement: emp, true),
                                .montrer(joueur: j, emplacement: emp, face: carte, true)],
                               .retournement, attente: r.duree(0.45)))
                e.append(Etape([.ecarter(joueur: j, emplacement: emp, carte: carte)], .vol,
                               attente: r.duree(0.9), haptique: j == moi ? .succes : .leger,
                               annonce: .reflexeReussi(joueur: j)))

            case .reflexeRate(let j, let emp, let montree, let penalite):
                e.append(Etape([.soulever(joueur: j, emplacement: emp, true),
                                .montrer(joueur: j, emplacement: emp, face: montree, true)],
                               .retournement, attente: r.duree(1.0),
                               haptique: j == moi ? .erreur : nil, annonce: .reflexeRate(joueur: j)))
                e.append(Etape([.montrer(joueur: j, emplacement: emp, face: nil, false),
                                .soulever(joueur: j, emplacement: emp, false)],
                               .retournement, attente: r.duree(0.4)))
                if penalite {
                    e.append(Etape([.penalite(joueur: j)], .vol, attente: r.duree(0.9),
                                   haptique: j == moi ? .avertissement : nil, annonce: .plusUn(joueur: j)))
                }

            case .reflexePasse:
                break

            case .tourSuivant(let j):
                e.append(Etape([], .immediat, attente: r.duree(0.3),
                               haptique: j == moi ? .selection : nil,
                               annonce: j == moi ? .aToi : nil))

            case .cochon(let j, let n):
                e.append(Etape([], .immediat, attente: r.duree(1.8), haptique: .fort,
                               annonce: .cochon(joueur: j, toursRestants: n)))

            case .finDeManche:
                // Révélation joueur par joueur, en commençant par moi.
                let n = vue.nombreJoueurs
                for k in 0..<n {
                    let p = (moi + k) % n
                    let cartes = vue.mains[p].compactMap { $0 }
                    e.append(Etape([.reveler(joueur: p, cartes: cartes)], .retournement,
                                   attente: r.duree(0.45), haptique: k == 0 ? .leger : nil))
                }
                e.append(Etape([], .immediat, attente: r.duree(0.6), haptique: .succes))
            }
        }
        return e
    }

    /// Joue plusieurs suites d'étapes en même temps (par exemple les
    /// ordinateurs qui regardent leurs cartes au départ) : la n-ième étape
    /// de chaque suite part ensemble, et on attend la plus longue.
    public static func simultanees(_ suites: [[Etape]]) -> [Etape] {
        let longueur = suites.map(\.count).max() ?? 0
        return (0..<longueur).map { i in
            let etapes = suites.compactMap { $0.indices.contains(i) ? $0[i] : nil }
            return Etape(etapes.flatMap(\.mouvements),
                         etapes.first?.style ?? .immediat,
                         attente: etapes.map(\.attente).max() ?? 0,
                         haptique: etapes.compactMap(\.haptique).first,
                         annonce: etapes.compactMap(\.annonce).first)
        }
    }

    /// Le joueur regarde sa carte : elle se soulève, se retourne, reste
    /// visible `tenir` secondes, se recache et se repose.
    private static func regard(joueur j: Int, emplacement emp: Int, face: Carte?, tenir: Double, _ r: Rythme) -> [Etape] {
        [
            Etape([.soulever(joueur: j, emplacement: emp, true)], .soulevement, attente: r.duree(0.18), haptique: .selection),
            Etape([.montrer(joueur: j, emplacement: emp, face: face, true)], .retournement, attente: r.duree(tenir)),
            Etape([.montrer(joueur: j, emplacement: emp, face: nil, false)], .retournement, attente: r.duree(0.36)),
            Etape([.soulever(joueur: j, emplacement: emp, false)], .soulevement, attente: r.duree(0.18)),
        ]
    }

    /// Un adversaire regarde sa carte : elle se soulève et s'incline vers
    /// lui, face cachée pour nous.
    private static func coupDOeil(joueur j: Int, emplacement emp: Int, tenir: Double, _ r: Rythme) -> [Etape] {
        [
            Etape([.soulever(joueur: j, emplacement: emp, true), .incliner(joueur: j, emplacement: emp, true)],
                  .soulevement, attente: r.duree(tenir)),
            Etape([.soulever(joueur: j, emplacement: emp, false), .incliner(joueur: j, emplacement: emp, false)],
                  .soulevement, attente: r.duree(0.18)),
        ]
    }
}
