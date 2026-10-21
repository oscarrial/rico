import Foundation

/// Una estancia que iOS detecta con la API de visitas (`CLVisit`), sin depender de CoreLocation.
public struct Estancia: Sendable, Equatable {
    public var latitud: Double
    public var longitud: Double
    public var llegada: Date
    /// `Date.distantFuture` mientras la persona sigue allí.
    public var salida: Date
    /// Radio de incertidumbre de la posición, en metros.
    public var precisionMetros: Double

    public init(latitud: Double, longitud: Double, llegada: Date, salida: Date, precisionMetros: Double) {
        self.latitud = latitud
        self.longitud = longitud
        self.llegada = llegada
        self.salida = salida
        self.precisionMetros = precisionMetros
    }

    public var duracion: TimeInterval { salida.timeIntervalSince(llegada) }
}

/// Un sitio de Apple Maps cerca de la estancia.
public struct CandidatoEstancia: Sendable, Equatable {
    public var id: String
    public var nombre: String
    /// `MKPointOfInterestCategory.rawValue`, si Apple Maps la da.
    public var categoria: String?
    public var latitud: Double
    public var longitud: Double

    public init(id: String, nombre: String, categoria: String?, latitud: Double, longitud: Double) {
        self.id = id
        self.nombre = nombre
        self.categoria = categoria
        self.latitud = latitud
        self.longitud = longitud
    }
}

public enum DecisionEstancia: Sendable, Equatable {
    public enum Motivo: Sendable, Equatable {
        /// La persona sigue allí: se decide al salir.
        case enCurso
        /// Menos del mínimo: un café rápido o pasar por delante.
        case corta
        /// Demasiado larga para una comida: casa, trabajo, un hotel.
        case larga
        /// La posición es demasiado imprecisa para saber en qué sitio estaba.
        case imprecisa
        /// Ya hay una visita (de un pago o apuntada a mano) a esa hora.
        case yaRegistrada
        /// No hay ningún sitio para comer lo bastante cerca.
        case sinCandidatos
    }

    case ignorar(Motivo)
    /// Preguntar «¿Has comido en …?» por ese candidato.
    case preguntar(candidatoID: String, distanciaMetros: Double)
}

/// Decide si una estancia fue una comida y en qué sitio. Lógica pura para poder probarla.
public struct EvaluadorEstancia: Sendable {
    /// El plan: estancias de 40 minutos o más.
    public var duracionMinima: TimeInterval
    /// Más de esto no es una comida; evita preguntar por casa o por el trabajo.
    public var duracionMaxima: TimeInterval
    /// Distancia máxima entre la estancia y el sitio.
    public var radioMetros: Double
    /// Por encima de esta incertidumbre no se pregunta.
    public var precisionMaxima: Double
    /// Margen alrededor de la estancia para considerar que una visita ya la cubre.
    public var margenRegistrada: TimeInterval

    public init(
        duracionMinima: TimeInterval = 40 * 60,
        duracionMaxima: TimeInterval = 4 * 3600,
        radioMetros: Double = 75,
        precisionMaxima: Double = 200,
        margenRegistrada: TimeInterval = 45 * 60
    ) {
        self.duracionMinima = duracionMinima
        self.duracionMaxima = duracionMaxima
        self.radioMetros = radioMetros
        self.precisionMaxima = precisionMaxima
        self.margenRegistrada = margenRegistrada
    }

    /// - Parameters:
    ///   - registradas: fechas de las visitas ya guardadas ese día (pagos, manuales u otras estancias).
    ///   - silenciados: ids de sitios por los que el usuario pidió no volver a preguntar.
    public func decidir(
        _ estancia: Estancia,
        candidatos: [CandidatoEstancia],
        registradas: [Date] = [],
        silenciados: Set<String> = []
    ) -> DecisionEstancia {
        guard estancia.salida != .distantFuture else { return .ignorar(.enCurso) }
        guard estancia.duracion >= duracionMinima else { return .ignorar(.corta) }
        guard estancia.duracion <= duracionMaxima else { return .ignorar(.larga) }
        guard estancia.precisionMetros <= precisionMaxima else { return .ignorar(.imprecisa) }

        let desde = estancia.llegada.addingTimeInterval(-margenRegistrada)
        let hasta = estancia.salida.addingTimeInterval(margenRegistrada)
        if registradas.contains(where: { $0 >= desde && $0 <= hasta }) { return .ignorar(.yaRegistrada) }

        // La imprecisión ensancha un poco el radio, sin pasar del doble.
        let radio = radioMetros + min(estancia.precisionMetros, radioMetros)
        let mejor = candidatos
            .filter { !silenciados.contains($0.id) }
            .filter { FiltroSitios.esValido(nombre: $0.nombre, categoria: $0.categoria, permitidas: FiltroSitios.restauracion) }
            .map { ($0, DistanciaGeo.metros(estancia.latitud, estancia.longitud, $0.latitud, $0.longitud)) }
            .filter { $0.1 <= radio }
            .min { $0.1 < $1.1 }

        guard let mejor else { return .ignorar(.sinCandidatos) }
        return .preguntar(candidatoID: mejor.0.id, distanciaMetros: mejor.1)
    }
}
