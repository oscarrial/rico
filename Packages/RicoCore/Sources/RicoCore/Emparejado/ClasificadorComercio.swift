import Foundation

/// Reconoce comercios que no son restauración para no molestar al usuario con ellos.
/// Lista inicial: se ampliará con los datos de la beta.
public enum ClasificadorComercio {
    static let palabras: Set<String> = [
        // Supermercados
        "mercadona", "carrefour", "lidl", "aldi", "eroski", "gadis", "froiz", "alcampo",
        "hipercor", "consum", "caprabo", "bonpreu", "ahorramas", "supermercado", "hipermercado",
        // Gasolineras y transporte
        "repsol", "cepsa", "galp", "shell", "bp", "petroprix", "plenoil", "ballenoil", "gasolinera",
        "renfe", "parking", "aparcamiento", "cabify", "bolt", "autopista", "peaje",
        // Tiendas y servicios
        "farmacia", "zara", "primark", "ikea", "decathlon", "mediamarkt", "amazon", "apple",
        "fnac", "leroy", "druni", "primor", "estanco", "lavanderia", "gimnasio", "taxi"
    ]

    static let frases: [String] = [
        "estacion de servicio", "el corte ingles supermercado", "leroy merlin", "media markt"
    ]

    /// - Parameter limpio: nombre ya pasado por `LimpiadorComercio.limpiar`.
    public static func esNoRestauracion(_ limpio: String) -> Bool {
        let tokens = LimpiadorComercio.tokens(limpio)
        if tokens.contains(where: palabras.contains) { return true }
        return frases.contains { limpio.contains($0) }
    }
}
