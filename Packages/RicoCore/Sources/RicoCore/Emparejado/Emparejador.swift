import Foundation

/// Un restaurante cercano al sitio del pago.
public struct CandidatoLugar: Sendable, Hashable {
    /// `mapItemID` de Apple Maps o id local del restaurante.
    public var id: String
    public var nombre: String
    public var distanciaMetros: Double?
    public var visitadoAntes: Bool

    public init(id: String, nombre: String, distanciaMetros: Double?, visitadoAntes: Bool = false) {
        self.id = id
        self.nombre = nombre
        self.distanciaMetros = distanciaMetros
        self.visitadoAntes = visitadoAntes
    }
}

public struct CandidatoPuntuado: Sendable, Hashable {
    public var candidato: CandidatoLugar
    public var puntuacion: Double
    public var similitudTexto: Double
}

public enum DecisionEmparejado: Sendable, Equatable {
    /// Se asigna sin preguntar.
    case asignado(id: String, puntuacion: Double, porAlias: Bool)
    /// La notificación propone hasta 3 candidatos, el mejor primero.
    case proponer([CandidatoPuntuado])
    /// Queda en la bandeja para que el usuario elija (puede no haber candidatos).
    case bandeja([CandidatoPuntuado])
    /// Súper, gasolinera, tienda…: se guarda descartado y no molesta.
    case noRestauracion
}

/// Empareja el nombre de un pago con los restaurantes cercanos.
/// Puntuación = 60 % texto (Jaro-Winkler) + 30 % cercanía + 10 % si ya lo visitaste.
public struct Emparejador: Sendable {
    public var umbralAsignar: Double
    public var umbralProponer: Double
    public var radioMetros: Double
    public var maximoPropuestas: Int

    public init(umbralAsignar: Double = 0.75, umbralProponer: Double = 0.45, radioMetros: Double = 150, maximoPropuestas: Int = 3) {
        self.umbralAsignar = umbralAsignar
        self.umbralProponer = umbralProponer
        self.radioMetros = radioMetros
        self.maximoPropuestas = maximoPropuestas
    }

    /// - Parameter alias: comercio limpio → id de restaurante, aprendido de las correcciones del usuario.
    public func decidir(comercio: String, candidatos: [CandidatoLugar], alias: [String: String] = [:]) -> DecisionEmparejado {
        let limpio = LimpiadorComercio.limpiar(comercio)

        if let id = alias[limpio] {
            return .asignado(id: id, puntuacion: 1, porAlias: true)
        }
        if ClasificadorComercio.esNoRestauracion(limpio) {
            return .noRestauracion
        }

        let puntuados = puntuar(comercioLimpio: limpio, candidatos: candidatos)
        guard let mejor = puntuados.first else { return .bandeja([]) }

        let propuestas = Array(puntuados.prefix(maximoPropuestas))
        if mejor.puntuacion > umbralAsignar {
            return .asignado(id: mejor.candidato.id, puntuacion: mejor.puntuacion, porAlias: false)
        }
        if mejor.puntuacion >= umbralProponer {
            return .proponer(propuestas)
        }
        return .bandeja(propuestas)
    }

    /// Candidatos ordenados de mejor a peor.
    public func puntuar(comercioLimpio: String, candidatos: [CandidatoLugar]) -> [CandidatoPuntuado] {
        candidatos
            .map { candidato in
                let texto = Self.similitudTexto(comercioLimpio, LimpiadorComercio.limpiar(candidato.nombre))
                let cercania = candidato.distanciaMetros.map { max(0, 1 - $0 / radioMetros) } ?? 0
                let visitado = candidato.visitadoAntes ? 1.0 : 0
                let total = 0.6 * texto + 0.3 * cercania + 0.1 * visitado
                return CandidatoPuntuado(candidato: candidato, puntuacion: total, similitudTexto: texto)
            }
            .sorted { $0.puntuacion > $1.puntuacion }
    }

    /// Jaro-Winkler sobre el texto tal cual y con las palabras ordenadas; si las palabras de uno
    /// están todas en el otro («o grelo» y «taberna o grelo») se considera casi igual.
    public static func similitudTexto(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 1 }

        let tokensA = LimpiadorComercio.tokens(a)
        let tokensB = LimpiadorComercio.tokens(b)
        var similitud = max(
            JaroWinkler.similitud(a, b),
            JaroWinkler.similitud(tokensA.sorted().joined(separator: " "), tokensB.sorted().joined(separator: " "))
        )

        let conjuntoA = Set(tokensA), conjuntoB = Set(tokensB)
        if conjuntoA.isSubset(of: conjuntoB) || conjuntoB.isSubset(of: conjuntoA) {
            similitud = max(similitud, 0.92)
        }
        return similitud
    }
}
