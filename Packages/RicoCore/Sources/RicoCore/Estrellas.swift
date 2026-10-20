import Foundation

/// Reglas de la nota de 0,5 a 5 en medias estrellas.
public enum Estrellas {
    public static let minimo = 0.5
    public static let maximo = 5.0

    /// Tocar una estrella pone esa nota; tocar la misma otra vez deja media menos.
    public static func alTocar(estrella n: Int, actual: Double) -> Double {
        let entera = Double(min(max(n, 1), 5))
        return actual == entera ? entera - 0.5 : entera
    }

    /// Ajusta a medias estrellas dentro del rango.
    public static func normalizar(_ valor: Double) -> Double {
        let medio = (valor * 2).rounded() / 2
        return min(max(medio, minimo), maximo)
    }

    /// Relleno de la estrella n (1...5) para una nota: 0, 0,5 o 1.
    public static func relleno(estrella n: Int, nota: Double) -> Double {
        if nota >= Double(n) { return 1 }
        if nota >= Double(n) - 0.5 { return 0.5 }
        return 0
    }
}
