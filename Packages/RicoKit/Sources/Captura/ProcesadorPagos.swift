import Foundation
import SwiftData
import Modelos
import RicoCore

/// Qué pasó con un pago recibido del atajo.
public enum ResultadoCaptura: Sendable, Equatable {
    /// Restaurante reconocido: hay una visita en borrador lista para valorar.
    case asignado(visita: UUID)
    /// Hay un sitio probable, pero el usuario tiene que confirmarlo.
    case propuesto(visita: UUID)
    /// No se sabe dónde fue: espera en la bandeja.
    case pendiente(visita: UUID)
    /// Súper, gasolinera, tienda…
    case descartado
    /// El mismo pago llegó dos veces.
    case duplicado
    /// Importe por debajo del mínimo o tarjeta no vigilada.
    case ignorado
    /// No se pudo leer el importe o guardar el pago.
    case fallido
    /// Era un restaurante, pero el plan gratis ya usó su captura de este mes.
    case limiteGratis

    public var visita: UUID? {
        switch self {
        case let .asignado(id), let .propuesto(id), let .pendiente(id): id
        case .descartado, .duplicado, .ignorado, .fallido, .limiteGratis: nil
        }
    }
}

/// Recibe un pago del atajo de Apple Pay y lo convierte en una visita por valorar.
///
/// 1. Lee el importe («48,00 €») y filtra repetidos, importes pequeños y comercios que no son restauración.
/// 2. Busca el sitio: nombres que el usuario ya corrigió, restaurantes del diario y, si hay ubicación,
///    Apple Maps alrededor.
/// 3. Crea una visita en borrador con el importe y programa el aviso para valorarla.
@MainActor
public final class ProcesadorPagos {
    private let contexto: ModelContext
    private let buscador: (any BuscadorLugaresCercanos)?
    private let ubicacion: (any ProveedorUbicacion)?
    private let notificador: (any Notificador)?
    private let filtro: FiltroPagos
    private let emparejador: Emparejador
    private let ahora: () -> Date

    /// Tiempo entre el pago y el aviso para valorar.
    public var retrasoAviso: TimeInterval = 20 * 60
    /// Radio de búsqueda en Apple Maps alrededor del pago.
    public var radioBusqueda: Double = 300
    /// Visitas por pago que se pueden crear al mes; `nil` es sin límite (Premium).
    public var limiteMensual: Int?

    public init(
        contexto: ModelContext,
        buscador: (any BuscadorLugaresCercanos)? = nil,
        ubicacion: (any ProveedorUbicacion)? = nil,
        notificador: (any Notificador)? = nil,
        filtro: FiltroPagos = FiltroPagos(),
        emparejador: Emparejador = Emparejador(),
        ahora: @escaping () -> Date = { .now }
    ) {
        self.contexto = contexto
        self.buscador = buscador
        self.ubicacion = ubicacion
        self.notificador = notificador
        self.filtro = filtro
        self.emparejador = emparejador
        self.ahora = ahora
    }

    /// Nunca lanza: los fallos se registran y devuelven `.fallido`.
    @discardableResult
    public func procesar(comercio: String, importe textoImporte: String, tarjeta: String? = nil) async -> ResultadoCaptura {
        let comercio = comercio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !comercio.isEmpty else {
            Registro.captura.error("Pago sin comercio")
            return .fallido
        }
        guard let importe = Self.leerImporte(textoImporte) else {
            Registro.captura.error("Importe ilegible: \(textoImporte, privacy: .private)")
            return .fallido
        }
        let tarjeta = tarjeta?.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacio
        let fecha = ahora()

        do {
            return try await procesar(PagoEntrante(comercio: comercio, importe: importe, fecha: fecha, tarjeta: tarjeta))
        } catch {
            contexto.rollback()
            Registro.captura.error("No se pudo guardar el pago: \(String(describing: error), privacy: .public)")
            return .fallido
        }
    }

    private func procesar(_ entrante: PagoEntrante) async throws -> ResultadoCaptura {
        let pago = PagoCapturado(comercioBruto: entrante.comercio, importe: entrante.importe, fecha: entrante.fecha, tarjeta: entrante.tarjeta)

        // Repetidos, importe mínimo y tarjetas.
        switch filtro.evaluar(entrante, recientes: try pagosRecientes(antesDe: entrante.fecha)) {
        case .aceptar:
            break
        case .duplicado:
            return try guardar(pago, estado: .duplicado, resultado: .duplicado)
        case .ignorarImporte, .ignorarTarjeta:
            return try guardar(pago, estado: .ignorado, resultado: .ignorado)
        }

        // Un nombre que el usuario ya corrigió manda sobre todo lo demás.
        if let restaurante = try restauranteAprendido(pago.comercioLimpio) {
            return try await crearVisita(pago, restaurante: restaurante, estado: .asignado, puntuacion: 1)
        }
        if ClasificadorComercio.esNoRestauracion(pago.comercioLimpio) {
            return try guardar(pago, estado: .descartado, resultado: .descartado)
        }

        let posicion = await ubicacion?.ubicacionActual()
        pago.latitud = posicion?.latitud
        pago.longitud = posicion?.longitud

        // Primero los restaurantes del diario; si no hay uno claro, Apple Maps alrededor.
        let delDiario = try candidatosDelDiario(comercioLimpio: pago.comercioLimpio, cerca: posicion)
        var candidatos = delDiario.map { $0.candidato }
        var decision = emparejador.decidir(comercio: entrante.comercio, candidatos: candidatos)
        var lugares: [String: LugarEncontrado] = [:]

        if !decision.esAsignado, let posicion, let buscador {
            do {
                let encontrados = try await buscador.buscar(pago.comercioLimpio, cerca: posicion, radioMetros: radioBusqueda)
                let conocidos = Set(delDiario.compactMap { $0.restaurante.mapItemID })
                for lugar in encontrados {
                    if let mapItemID = lugar.mapItemID, conocidos.contains(mapItemID) { continue }
                    let id = "mapa:\(lugar.id)"
                    guard lugares[id] == nil else { continue }
                    lugares[id] = lugar
                    candidatos.append(CandidatoLugar(
                        id: id,
                        nombre: lugar.nombre,
                        distanciaMetros: posicion.metros(hasta: lugar.latitud, lugar.longitud)
                    ))
                }
                decision = emparejador.decidir(comercio: entrante.comercio, candidatos: candidatos)
            } catch {
                Registro.captura.notice("Falló la búsqueda de sitios cercanos: \(String(describing: error), privacy: .public)")
            }
        }

        let porID = Dictionary(delDiario.map { ($0.candidato.id, $0.restaurante) }, uniquingKeysWith: { primero, _ in primero })
        func restaurante(_ id: String) throws -> Restaurante? {
            if let local = porID[id] { return local }
            if let lugar = lugares[id] { return try contexto.restaurante(para: lugar) }
            return nil
        }

        switch decision {
        case let .asignado(id, puntuacion, _):
            return try await crearVisita(pago, restaurante: try restaurante(id), estado: .asignado, puntuacion: puntuacion)
        case let .proponer(propuestas):
            let mejor = propuestas.first
            return try await crearVisita(
                pago,
                restaurante: try mejor.flatMap { try restaurante($0.candidato.id) },
                estado: .propuesto,
                puntuacion: mejor?.puntuacion
            )
        case let .bandeja(propuestas):
            return try await crearVisita(pago, restaurante: nil, estado: .pendiente, puntuacion: propuestas.first?.puntuacion)
        case .noRestauracion:
            return try guardar(pago, estado: .descartado, resultado: .descartado)
        }
    }

    // MARK: Pasos

    private func guardar(_ pago: PagoCapturado, estado: EstadoPago, resultado: ResultadoCaptura) throws -> ResultadoCaptura {
        pago.estado = estado
        contexto.insert(pago)
        try contexto.save()
        return resultado
    }

    private func crearVisita(_ pago: PagoCapturado, restaurante: Restaurante?, estado propuesto: EstadoPago, puntuacion: Double?) async throws -> ResultadoCaptura {
        // Plan gratis: si ya se usó la captura del mes, el pago se guarda pero no crea visita.
        if let limiteMensual, try contexto.capturasDelMes(pago.fecha) >= limiteMensual {
            pago.puntuacionEmparejado = puntuacion
            return try guardar(pago, estado: .ignorado, resultado: .limiteGratis)
        }
        // Sin restaurante no hay nada que proponer: queda pendiente.
        let estado: EstadoPago = restaurante == nil ? .pendiente : propuesto
        pago.estado = estado
        pago.puntuacionEmparejado = puntuacion
        contexto.insert(pago)

        let visita = Visita(fecha: pago.fecha, origen: .pago)
        visita.estado = .borrador
        contexto.insert(visita)
        visita.importe = pago.importe
        visita.restaurante = restaurante
        visita.pago = pago
        try contexto.save()

        Registro.captura.info("Pago guardado como \(estado.rawValue, privacy: .public)")
        await notificador?.programarValoracion(
            visitaID: visita.id,
            sitio: estado == .asignado ? restaurante?.nombre : nil,
            importe: pago.importe,
            retraso: retrasoAviso
        )

        return switch estado {
        case .asignado: .asignado(visita: visita.id)
        case .propuesto: .propuesto(visita: visita.id)
        default: .pendiente(visita: visita.id)
        }
    }

    private func pagosRecientes(antesDe fecha: Date) throws -> [PagoEntrante] {
        let desde = fecha.addingTimeInterval(-filtro.ventanaDuplicado)
        let descriptor = FetchDescriptor<PagoCapturado>(predicate: #Predicate { $0.fecha >= desde })
        return try contexto.fetch(descriptor).map {
            PagoEntrante(comercio: $0.comercioBruto, importe: $0.importe, fecha: $0.fecha, tarjeta: $0.tarjeta)
        }
    }

    private func restauranteAprendido(_ comercioLimpio: String) throws -> Restaurante? {
        guard !comercioLimpio.isEmpty else { return nil }
        let descriptor = FetchDescriptor<AliasComercio>(
            predicate: #Predicate { $0.comercioLimpio == comercioLimpio },
            sortBy: [SortDescriptor(\.vecesConfirmado, order: .reverse)]
        )
        return try contexto.fetch(descriptor).lazy.compactMap(\.restaurante).first
    }

    /// Restaurantes del diario que están cerca del pago o se llaman casi igual. El resto no se
    /// tiene en cuenta: sin cercanía, un nombre parecido a medias no basta para proponerlo.
    private func candidatosDelDiario(comercioLimpio: String, cerca posicion: Coordenada?) throws -> [(candidato: CandidatoLugar, restaurante: Restaurante)] {
        try contexto.fetch(FetchDescriptor<Restaurante>()).compactMap { (restaurante: Restaurante) -> (candidato: CandidatoLugar, restaurante: Restaurante)? in
            var distancia: Double?
            if let posicion, let lat = restaurante.latitud, let lon = restaurante.longitud {
                distancia = posicion.metros(hasta: lat, lon)
            }
            let cerca = distancia.map { $0 <= emparejador.radioMetros } ?? false
            let parecido = Emparejador.similitudTexto(comercioLimpio, LimpiadorComercio.limpiar(restaurante.nombre)) >= 0.85
            guard cerca || parecido else { return nil }
            let visitado = (restaurante.visitas ?? []).contains { $0.estado == .valorada }
            let candidato = CandidatoLugar(
                id: restaurante.id.uuidString,
                nombre: restaurante.nombre,
                distanciaMetros: distancia,
                visitadoAntes: visitado
            )
            return (candidato: candidato, restaurante: restaurante)
        }
    }

    /// Lee importes como los manda Atajos: «48,00 €», «1.234,56 €», «€48.00», «48,00 EUR», «-48,00».
    public static func leerImporte(_ texto: String) -> Importe? {
        let mayusculas = texto.uppercased()
        let divisa: String = if mayusculas.contains("$") || mayusculas.contains("USD") {
            "USD"
        } else if mayusculas.contains("£") || mayusculas.contains("GBP") {
            "GBP"
        } else {
            "EUR"
        }
        let cifras = texto.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }
        let recortado = cifras.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
        guard !recortado.isEmpty else { return nil }
        return Importe(texto: recortado, divisa: divisa)
    }
}

public extension ModelContext {
    /// Visitas creadas por pagos de Apple Pay en el mes de `fecha`. Las descartadas («no era
    /// un restaurante») no cuentan, para no gastar la captura gratis en un error.
    func capturasDelMes(_ fecha: Date, calendario: Calendar = .current) throws -> Int {
        guard let mes = calendario.dateInterval(of: .month, for: fecha) else { return 0 }
        let inicio = mes.start
        let fin = mes.end
        let pago = OrigenVisita.pago.rawValue
        let descartada = EstadoVisita.descartada.rawValue
        let descriptor = FetchDescriptor<Visita>(predicate: #Predicate {
            $0.origenRaw == pago && $0.estadoRaw != descartada && $0.fecha >= inicio && $0.fecha < fin
        })
        return try fetchCount(descriptor)
    }
}

private extension DecisionEmparejado {
    var esAsignado: Bool {
        if case .asignado = self { return true }
        return false
    }
}

extension String {
    var nilSiVacio: String? {
        let recortado = trimmingCharacters(in: .whitespacesAndNewlines)
        return recortado.isEmpty ? nil : recortado
    }
}
