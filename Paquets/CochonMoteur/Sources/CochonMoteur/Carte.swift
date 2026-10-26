// Les 52 cartes françaises et leur valeur au décompte.

public enum Couleur: Int, CaseIterable, Sendable, Comparable {
    case trefle = 0, carreau, coeur, pique

    /// Rouge ou noire : seul le Roi en dépend (noir = 0, rouge = 30).
    public var estRouge: Bool { self == .carreau || self == .coeur }

    public var symbole: String {
        switch self {
        case .trefle: return "♣"
        case .carreau: return "♦"
        case .coeur: return "♥"
        case .pique: return "♠"
        }
    }

    /// Code ASCII stable du format d'échange (JSON) : T, K, C, P.
    public var code: String {
        switch self {
        case .trefle: return "T"
        case .carreau: return "K"
        case .coeur: return "C"
        case .pique: return "P"
        }
    }

    public static func < (a: Couleur, b: Couleur) -> Bool { a.rawValue < b.rawValue }
}

public enum Rang: Int, CaseIterable, Sendable, Comparable {
    /// `un` est l'As (`as` est un mot réservé de Swift).
    case un = 1, deux, trois, quatre, cinq, six, sept, huit, neuf, dix
    case valet, dame, roi

    /// Code ASCII stable du format d'échange : A, 2…10, V, D, R.
    public var code: String {
        switch self {
        case .un: return "A"
        case .valet: return "V"
        case .dame: return "D"
        case .roi: return "R"
        default: return String(rawValue)
        }
    }

    public static func < (a: Rang, b: Rang) -> Bool { a.rawValue < b.rawValue }
}

/// Une carte. Les 52 cartes sont toutes différentes : une carte suffit à
/// désigner sa place, ce qui simplifie le suivi de « qui a vu quoi ».
public struct Carte: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rang: Rang
    public let couleur: Couleur

    public init(_ rang: Rang, _ couleur: Couleur) {
        self.rang = rang
        self.couleur = couleur
    }

    /// Valeur au décompte : As = 1, 2 à 10 = leur valeur, Valet et Dame = 10,
    /// Rois noirs = 0, Rois rouges = 30.
    public var valeur: Int {
        switch rang {
        case .valet, .dame: return 10
        case .roi: return couleur.estRouge ? 30 : 0
        default: return rang.rawValue
        }
    }

    /// Numéro de 0 à 51, stable (sert aux ensembles de cartes en bits).
    public var numero: Int { (rang.rawValue - 1) * 4 + couleur.rawValue }

    public init?(numero: Int) {
        guard (0..<52).contains(numero),
              let r = Rang(rawValue: numero / 4 + 1),
              let c = Couleur(rawValue: numero % 4) else { return nil }
        self.init(r, c)
    }

    /// Code d'échange, par exemple « 10C » (dix de cœur) ou « RP » (roi de pique).
    public var code: String { rang.code + couleur.code }

    public init?(code: String) {
        guard let derniere = code.last,
              let c = Couleur.allCases.first(where: { $0.code == String(derniere) }),
              let r = Rang.allCases.first(where: { $0.code == String(code.dropLast()) })
        else { return nil }
        self.init(r, c)
    }

    public var description: String { rang.code + couleur.symbole }

    public static func < (a: Carte, b: Carte) -> Bool { a.numero < b.numero }

    /// Le paquet complet, dans un ordre fixe (avant mélange).
    public static let paquetComplet: [Carte] = (0..<52).compactMap { Carte(numero: $0) }
}

extension Carte: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let texte = try c.decode(String.self)
        guard let carte = Carte(code: texte) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "carte inconnue : \(texte)")
        }
        self = carte
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(code)
    }
}

/// Ensemble de cartes rangé dans 52 bits. Contrairement à `Set`, son
/// encodage est toujours le même d'une machine à l'autre : deux états égaux
/// donnent le même JSON, ce qu'il faut pour comparer client et serveur.
public struct EnsembleCartes: Hashable, Sendable, Codable, Sequence {
    public private(set) var bits: UInt64

    public init() { bits = 0 }
    public init<S: Sequence>(_ cartes: S) where S.Element == Carte {
        bits = 0
        for c in cartes { insert(c) }
    }

    public func contains(_ c: Carte) -> Bool { bits & (1 << UInt64(c.numero)) != 0 }
    public mutating func insert(_ c: Carte) { bits |= 1 << UInt64(c.numero) }
    public mutating func remove(_ c: Carte) { bits &= ~(1 << UInt64(c.numero)) }
    public mutating func formUnion(_ autre: EnsembleCartes) { bits |= autre.bits }
    public var count: Int { bits.nonzeroBitCount }
    public var isEmpty: Bool { bits == 0 }

    public func makeIterator() -> IndexingIterator<[Carte]> {
        Carte.paquetComplet.filter { contains($0) }.makeIterator()
    }

    public init(from decoder: Decoder) throws {
        bits = try decoder.singleValueContainer().decode(UInt64.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(bits)
    }
}
