// Hasard reproductible : une graine donne toujours la même donne, sur
// iPhone comme sur un serveur Linux. On n'utilise ni `shuffled()` ni le
// générateur du système, dont l'algorithme n'est pas garanti stable.

/// SplitMix64 (Steele, Lea, Flood 2014) : simple, rapide, bien étudié.
public struct GenerateurDeterministe: RandomNumberGenerator, Sendable {
    private var etat: UInt64

    public init(graine: UInt64) { etat = graine }

    public mutating func next() -> UInt64 {
        etat &+= 0x9E37_79B9_7F4A_7C15
        var z = etat
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Entier uniforme dans 0..<borne, sans biais (tirage par rejet).
    public mutating func uniforme(_ borne: Int) -> Int {
        precondition(borne > 0, "borne strictement positive")
        let b = UInt64(borne)
        let limite = UInt64.max - UInt64.max % b
        var x: UInt64
        repeat { x = next() } while x >= limite
        return Int(x % b)
    }

    /// Mélange de Fisher-Yates.
    public mutating func melanger<T>(_ elements: [T]) -> [T] {
        var t = elements
        var i = t.count - 1
        while i > 0 {
            t.swapAt(i, uniforme(i + 1))
            i -= 1
        }
        return t
    }

    /// Mélange plusieurs nombres en une graine (par exemple graine de partie,
    /// numéro du coup et joueur, pour le hasard de l'ordinateur).
    public static func graine(_ valeurs: UInt64...) -> UInt64 {
        var g = GenerateurDeterministe(graine: 0x434F_4348_4F4E_2121) // « COCHON!! »
        var h: UInt64 = 0
        for v in valeurs {
            g = GenerateurDeterministe(graine: g.next() ^ v)
            h = g.next()
        }
        return h
    }
}
