import Foundation

/// Junta los pines que se pisarían en pantalla. Divide la zona visible en una rejilla y cada
/// celda con más de un punto es un grupo: «6» en vez de seis pines uno encima de otro.
public enum AgrupadorPines {
    /// Celdas de la rejilla a lo ancho y a lo alto de la zona visible. Con un pin de 44 pt en un
    /// iPhone de unos 400 × 800 pt, 8 × 14 deja cada celda del tamaño de un pin y algo de aire.
    public static let celdasAncho = 8.0
    public static let celdasAlto = 14.0

    /// Índices de `puntos` agrupados por celda, en el orden en que aparece cada grupo.
    /// Con una zona sin tamaño, cada punto va solo.
    public static func grupos(
        _ puntos: [(latitud: Double, longitud: Double)],
        latitudDelta: Double,
        longitudDelta: Double
    ) -> [[Int]] {
        let alto = latitudDelta / celdasAlto
        let ancho = longitudDelta / celdasAncho
        guard alto > 0, ancho > 0 else { return puntos.indices.map { [$0] } }

        var orden: [Celda] = []
        var porCelda: [Celda: [Int]] = [:]
        for (indice, punto) in puntos.enumerated() {
            let celda = Celda(fila: Int((punto.latitud / alto).rounded(.down)), columna: Int((punto.longitud / ancho).rounded(.down)))
            if porCelda[celda] == nil { orden.append(celda) }
            porCelda[celda, default: []].append(indice)
        }
        return orden.compactMap { porCelda[$0] }
    }

    private struct Celda: Hashable {
        let fila: Int
        let columna: Int
    }
}
