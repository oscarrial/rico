import Foundation

/// Similitud de Jaro-Winkler entre 0 y 1.
public enum JaroWinkler {
    public static func similitud(_ a: String, _ b: String, escala: Double = 0.1) -> Double {
        let s1 = Array(a), s2 = Array(b)
        if s1.isEmpty && s2.isEmpty { return 1 }
        if s1.isEmpty || s2.isEmpty { return 0 }

        let ventana = max(max(s1.count, s2.count) / 2 - 1, 0)
        var coincide1 = [Bool](repeating: false, count: s1.count)
        var coincide2 = [Bool](repeating: false, count: s2.count)
        var coincidencias = 0

        for i in s1.indices {
            let desde = max(0, i - ventana)
            let hasta = min(i + ventana + 1, s2.count)
            guard desde < hasta else { continue }
            for j in desde..<hasta where !coincide2[j] && s1[i] == s2[j] {
                coincide1[i] = true
                coincide2[j] = true
                coincidencias += 1
                break
            }
        }
        guard coincidencias > 0 else { return 0 }

        var transposiciones = 0
        var k = 0
        for i in s1.indices where coincide1[i] {
            while !coincide2[k] { k += 1 }
            if s1[i] != s2[k] { transposiciones += 1 }
            k += 1
        }

        let m = Double(coincidencias)
        let jaro = (m / Double(s1.count) + m / Double(s2.count) + (m - Double(transposiciones / 2)) / m) / 3

        var prefijo = 0
        for (c1, c2) in zip(s1, s2).prefix(4) {
            guard c1 == c2 else { break }
            prefijo += 1
        }
        return jaro + Double(prefijo) * escala * (1 - jaro)
    }
}
