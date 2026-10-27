import Foundation

/// Una estancia que iOS detecta con la API de visitas (`CLVisit`), sin depender de CoreLocation.
public struct Estancia: Sendable, Equatable {
    public var latitud: Double
    public var longitud: Double
    /// `Date.distantPast` cuando iOS no vio la llegada.
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

/// Un sitio donde la persona ha dormido (casa, hotel, la casa de un amigo). Por los bares de al
/// lado no se pregunta: pasar la tarde en el hotel no es comer en el bar de abajo.
public struct LugarDormido: Sendable, Equatable, Codable {
    public var latitud: Double
    public var longitud: Double
    public var fecha: Date

    public init(latitud: Double, longitud: Double, fecha: Date) {
        self.latitud = latitud
        self.longitud = longitud
        self.fecha = fecha
    }
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
        /// No coincide con la hora de comer ni de cenar: un museo, la siesta, compras.
        case fueraDeHora
        /// Es donde la persona duerme (o ha dormido estos días): el hotel o casa.
        case dondeDuermes
        /// Ya hay una visita (de un pago o apuntada a mano) a esa hora.
        case yaRegistrada
        /// No hay ningún sitio para comer lo bastante cerca.
        case sinCandidatos
        /// Hay varios sitios casi a la misma distancia: mejor no adivinar.
        case ambigua
    }

    case ignorar(Motivo)
    /// Preguntar «¿Has comido en …?» por ese candidato.
    case preguntar(candidatoID: String, distanciaMetros: Double)
}

/// Decide si una estancia fue una comida y en qué sitio. Lógica pura para poder probarla.
///
/// En el centro de una ciudad hay un bar cada pocos metros: casi cualquier rato parado tiene uno
/// cerca. Por eso, además de la duración y la distancia, se exige que sea hora de comer o cenar,
/// que no sea donde duermes y que no haya duda entre varios sitios.
public struct EvaluadorEstancia: Sendable {
    /// Estancias de 40 minutos o más.
    public var duracionMinima: TimeInterval
    /// Más de esto no es una comida; evita preguntar por casa o por el trabajo.
    public var duracionMaxima: TimeInterval
    /// Distancia máxima base entre la estancia y el sitio.
    public var radioMetros: Double
    /// Por encima de esta incertidumbre no se pregunta.
    public var precisionMaxima: Double
    /// Margen alrededor de la estancia para considerar que una visita ya la cubre.
    public var margenRegistrada: TimeInterval
    /// Franjas de comida y cena, en minutos desde la medianoche (pueden pasar de 24 h).
    public var ventanasComida: [ClosedRange<Int>]
    /// Lo mínimo que la estancia tiene que coincidir con una franja de comida.
    public var solapeMinimo: TimeInterval
    /// Distancia a un sitio donde se ha dormido por debajo de la cual no se pregunta.
    public var distanciaNoche: Double
    /// Si el mejor sitio está a más de esto y el segundo casi igual de cerca, hay duda.
    public var distanciaSegura: Double
    /// Diferencia mínima entre el primer y el segundo sitio para no dudar.
    public var margenAmbiguo: Double
    public var calendario: Calendar

    public init(
        duracionMinima: TimeInterval = 40 * 60,
        duracionMaxima: TimeInterval = 4 * 3600,
        radioMetros: Double = 50,
        precisionMaxima: Double = 100,
        margenRegistrada: TimeInterval = 45 * 60,
        ventanasComida: [ClosedRange<Int>] = [(12 * 60 + 30)...(16 * 60 + 30), (20 * 60)...(24 * 60 + 30)],
        solapeMinimo: TimeInterval = 25 * 60,
        distanciaNoche: Double = 150,
        distanciaSegura: Double = 25,
        margenAmbiguo: Double = 15,
        calendario: Calendar = .current
    ) {
        self.duracionMinima = duracionMinima
        self.duracionMaxima = duracionMaxima
        self.radioMetros = radioMetros
        self.precisionMaxima = precisionMaxima
        self.margenRegistrada = margenRegistrada
        self.ventanasComida = ventanasComida
        self.solapeMinimo = solapeMinimo
        self.distanciaNoche = distanciaNoche
        self.distanciaSegura = distanciaSegura
        self.margenAmbiguo = margenAmbiguo
        self.calendario = calendario
    }

    /// - Parameters:
    ///   - registradas: fechas de las visitas ya guardadas ese día (pagos, manuales u otras estancias).
    ///   - silenciados: ids de sitios por los que el usuario pidió no volver a preguntar.
    ///   - noches: sitios donde la persona ha dormido estos días.
    public func decidir(
        _ estancia: Estancia,
        candidatos: [CandidatoEstancia],
        registradas: [Date] = [],
        silenciados: Set<String> = [],
        noches: [LugarDormido] = []
    ) -> DecisionEstancia {
        guard estancia.salida != .distantFuture else { return .ignorar(.enCurso) }
        guard estancia.duracion >= duracionMinima else { return .ignorar(.corta) }
        guard estancia.duracion <= duracionMaxima else { return .ignorar(.larga) }
        guard estancia.precisionMetros <= precisionMaxima else { return .ignorar(.imprecisa) }
        guard solapeConComidas(estancia) >= solapeMinimo else { return .ignorar(.fueraDeHora) }

        let dondeDuerme = noches.contains {
            DistanciaGeo.metros(estancia.latitud, estancia.longitud, $0.latitud, $0.longitud) <= distanciaNoche
        }
        guard !dondeDuerme else { return .ignorar(.dondeDuermes) }

        let desde = estancia.llegada.addingTimeInterval(-margenRegistrada)
        let hasta = estancia.salida.addingTimeInterval(margenRegistrada)
        if registradas.contains(where: { $0 >= desde && $0 <= hasta }) { return .ignorar(.yaRegistrada) }

        // La imprecisión ensancha un poco el radio, sin pasar del doble.
        let radio = radioMetros + min(estancia.precisionMetros, radioMetros)
        let cercanos = candidatos
            .filter { !silenciados.contains($0.id) }
            .filter { FiltroSitios.esValido(nombre: $0.nombre, categoria: $0.categoria, permitidas: FiltroSitios.restauracion) }
            .map { ($0, DistanciaGeo.metros(estancia.latitud, estancia.longitud, $0.latitud, $0.longitud)) }
            .filter { $0.1 <= radio }
            .sorted { $0.1 < $1.1 }

        guard let mejor = cercanos.first else { return .ignorar(.sinCandidatos) }
        if cercanos.count > 1, mejor.1 > distanciaSegura, cercanos[1].1 - mejor.1 < margenAmbiguo {
            return .ignorar(.ambigua)
        }
        return .preguntar(candidatoID: mejor.0.id, distanciaMetros: mejor.1)
    }

    /// Cuánto coincide la estancia con las franjas de comida y cena, sumando todos los días que toca.
    public func solapeConComidas(_ estancia: Estancia) -> TimeInterval {
        guard estancia.llegada != .distantPast, estancia.salida != .distantFuture else { return 0 }
        guard let primerDia = calendario.date(byAdding: .day, value: -1, to: calendario.startOfDay(for: estancia.llegada)) else { return 0 }
        var total: TimeInterval = 0
        var dia = primerDia
        while dia <= estancia.salida {
            for ventana in ventanasComida {
                guard
                    let inicio = calendario.date(byAdding: .minute, value: ventana.lowerBound, to: dia),
                    let fin = calendario.date(byAdding: .minute, value: ventana.upperBound, to: dia)
                else { continue }
                total += max(0, min(estancia.salida, fin).timeIntervalSince(max(estancia.llegada, inicio)))
            }
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: dia) else { break }
            dia = siguiente
        }
        return total
    }

    /// Una estancia de al menos 3 horas que pasa por las 4 de la madrugada: ahí se ha dormido.
    /// Si iOS no vio la llegada, se cuenta como noche si se sale entre las 4 y las 12.
    public func esNoche(_ estancia: Estancia) -> Bool {
        guard estancia.salida != .distantFuture else { return false }
        let llegada = estancia.llegada == .distantPast ? estancia.salida.addingTimeInterval(-8 * 3600) : estancia.llegada
        guard estancia.salida.timeIntervalSince(llegada) >= 3 * 3600 else { return false }
        var dia = calendario.startOfDay(for: llegada)
        while dia <= estancia.salida {
            if let cuatro = calendario.date(byAdding: .hour, value: 4, to: dia), cuatro >= llegada, cuatro <= estancia.salida {
                return true
            }
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: dia) else { break }
            dia = siguiente
        }
        return false
    }
}
