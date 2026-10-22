import Foundation
import SwiftData
import Testing
import Captura
import Modelos
import RicoCore

// MARK: Dobles

@MainActor
final class BuscadorCercanoFalso: BuscadorLugaresCercanos {
    var lugares: [LugarEncontrado] = []
    private(set) var consultas: [String] = []

    func buscar(_ texto: String, cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado] {
        consultas.append(texto)
        return lugares
    }
}

@MainActor
struct UbicacionFija: ProveedorUbicacion {
    var coordenada: Coordenada?

    func ubicacionActual() async -> Coordenada? { coordenada }
}

@MainActor
final class NotificadorFalso: Notificador {
    struct Aviso: Equatable {
        var visitaID: UUID
        var sitio: String?
    }

    private(set) var avisos: [Aviso] = []
    private(set) var cancelados: [UUID] = []

    func programarValoracion(visitaID: UUID, sitio: String?, importe: Importe, retraso: TimeInterval) async {
        avisos.append(Aviso(visitaID: visitaID, sitio: sitio))
    }

    func cancelar(visitaID: UUID) {
        cancelados.append(visitaID)
    }
}

// MARK: Pruebas

@MainActor
@Suite("Captura de pagos")
struct CapturaTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let buscador = BuscadorCercanoFalso()
    let notificador = NotificadorFalso()
    let ahora = Date(timeIntervalSince1970: 1_790_000_000)
    let vigo = Coordenada(latitud: 42.2406, longitud: -8.7207)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    private func procesador(ubicacion: Coordenada? = nil, ahora: Date? = nil) -> ProcesadorPagos {
        let momento = ahora ?? self.ahora
        return ProcesadorPagos(
            contexto: contexto,
            buscador: buscador,
            ubicacion: UbicacionFija(coordenada: ubicacion),
            notificador: notificador,
            ahora: { momento }
        )
    }

    private func visita(_ id: UUID?) throws -> Visita {
        let id = try #require(id)
        let descriptor = FetchDescriptor<Visita>(predicate: #Predicate { $0.id == id })
        return try #require(try contexto.fetch(descriptor).first)
    }

    @Test func aliasConocidoAsignaDirecto() async throws {
        let restaurante = Restaurante(nombre: "Casa Pepe")
        contexto.insert(restaurante)
        let alias = AliasComercio(comercioLimpio: LimpiadorComercio.limpiar("REST CASA PEPE SL"), restaurante: restaurante)
        contexto.insert(alias)
        try contexto.save()

        let resultado = await procesador(ubicacion: vigo).procesar(comercio: "REST CASA PEPE SL", importe: "48,00 €", tarjeta: "Visa")

        guard case .asignado = resultado else {
            Issue.record("Esperaba asignado y llegó \(resultado)")
            return
        }
        let borrador = try visita(resultado.visita)
        #expect(borrador.restaurante === restaurante)
        #expect(borrador.estado == .borrador)
        #expect(borrador.origen == .pago)
        #expect(borrador.importeCentimos == 4800)
        #expect(borrador.pago?.estado == .asignado)
        #expect(borrador.pago?.tarjeta == "Visa")
        #expect(buscador.consultas.isEmpty)
        #expect(notificador.avisos == [.init(visitaID: borrador.id, sitio: "Casa Pepe")])
    }

    @Test func comercioQueNoEsRestauracionSeDescarta() async throws {
        let resultado = await procesador().procesar(comercio: "MERCADONA VIGO", importe: "63,20 €")

        #expect(resultado == .descartado)
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 0)
        let pagos = try contexto.fetch(FetchDescriptor<PagoCapturado>())
        #expect(pagos.map(\.estado) == [.descartado])
        #expect(notificador.avisos.isEmpty)
    }

    @Test func mismoPagoDosVecesEsDuplicado() async throws {
        let primero = await procesador().procesar(comercio: "SUMUP *CAFE ALAMEDA", importe: "12,50 €")
        let segundo = await procesador(ahora: ahora.addingTimeInterval(90)).procesar(comercio: "SUMUP *CAFE ALAMEDA", importe: "12,50")

        #expect(primero.visita != nil)
        #expect(segundo == .duplicado)
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 1)
        #expect(notificador.avisos.count == 1)
    }

    @Test func sinCandidatosQuedaPendienteEnLaBandeja() async throws {
        let resultado = await procesador().procesar(comercio: "TPV 0042 LA TRASTIENDA", importe: "35,00 €")

        guard case .pendiente = resultado else {
            Issue.record("Esperaba pendiente y llegó \(resultado)")
            return
        }
        let borrador = try visita(resultado.visita)
        #expect(borrador.restaurante == nil)
        #expect(borrador.pago?.estado == .pendiente)
        #expect(try AccionesBandeja.pendientes(en: contexto).map(\.id) == [borrador.id])
        // Sin ubicación no se busca en el mapa ni se adivina el sitio en el aviso.
        #expect(buscador.consultas.isEmpty)
        #expect(notificador.avisos == [.init(visitaID: borrador.id, sitio: nil)])
    }

    @Test(arguments: [
        ("48,00 €", 4800),
        ("1.234,56 €", 123_456),
        ("€12.5", 1250),
        ("48,00 EUR", 4800),
        ("-23,40 €", 2340)
    ])
    func importeEnTextoEspanol(texto: String, centimos: Int) {
        #expect(ProcesadorPagos.leerImporte(texto)?.centimos == centimos)
        #expect(ProcesadorPagos.leerImporte(texto)?.divisa == "EUR")
    }

    @Test func importeIlegibleNoGuardaNada() async throws {
        let resultado = await procesador().procesar(comercio: "Casa Pepe", importe: "gratis")
        #expect(resultado == .fallido)
        #expect(try contexto.fetchCount(FetchDescriptor<PagoCapturado>()) == 0)
    }

    @Test func importePequenoSeIgnora() async throws {
        let resultado = await procesador().procesar(comercio: "Bar Manolo", importe: "1,80 €")
        #expect(resultado == .ignorado)
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 0)
    }

    @Test func restauranteCercanoEnElMapaSeAsigna() async throws {
        buscador.lugares = [
            LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: vigo.latitud, longitud: vigo.longitud)
        ]

        let resultado = await procesador(ubicacion: vigo).procesar(comercio: "TABERNA O GRELO S.L.", importe: "52,00 €")

        guard case .asignado = resultado else {
            Issue.record("Esperaba asignado y llegó \(resultado)")
            return
        }
        let borrador = try visita(resultado.visita)
        #expect(borrador.restaurante?.mapItemID == "I-GRELO")
        #expect(borrador.pago?.latitud == vigo.latitud)
        #expect(buscador.consultas == ["taberna grelo"])
    }

    @Test func restauranteDelDiarioCercanoSeAsignaSinBuscar() async throws {
        let restaurante = Restaurante(nombre: "Taberna O Grelo")
        restaurante.latitud = vigo.latitud
        restaurante.longitud = vigo.longitud
        contexto.insert(restaurante)
        try contexto.save()

        let resultado = await procesador(ubicacion: vigo).procesar(comercio: "TABERNA O GRELO", importe: "30,00 €")

        guard case .asignado = resultado else {
            Issue.record("Esperaba asignado y llegó \(resultado)")
            return
        }
        #expect(try visita(resultado.visita).restaurante === restaurante)
        #expect(buscador.consultas.isEmpty)
    }

    @Test func elegirSitioAprendeElNombreParaLaProxima() async throws {
        let primero = await procesador().procesar(comercio: "ZTL*LA TRASTIENDA", importe: "35,00 €")
        let borrador = try visita(primero.visita)
        let lugar = LugarEncontrado(mapItemID: "I-TRAS", nombre: "La Trastienda del Cuatro", ciudad: "Vigo", latitud: vigo.latitud, longitud: vigo.longitud)

        let restaurante = try AccionesBandeja.asignar(borrador, lugar: lugar, en: contexto)
        #expect(borrador.pago?.estado == .asignado)

        let segundo = await procesador(ahora: ahora.addingTimeInterval(86_400)).procesar(comercio: "ZTL*LA TRASTIENDA", importe: "20,00 €")
        guard case .asignado = segundo else {
            Issue.record("Esperaba asignado y llegó \(segundo)")
            return
        }
        #expect(try visita(segundo.visita).restaurante === restaurante)
    }

    @Test func noEraUnRestauranteBorraElBorrador() async throws {
        let resultado = await procesador().procesar(comercio: "LA TRASTIENDA", importe: "35,00 €")
        let borrador = try visita(resultado.visita)

        try AccionesBandeja.descartar(borrador, en: contexto)

        #expect(try AccionesBandeja.pendientes(en: contexto).isEmpty)
        let pagos = try contexto.fetch(FetchDescriptor<PagoCapturado>())
        #expect(pagos.map(\.estado) == [.descartado])
    }

    @Test func enlaceDeVisita() throws {
        let id = UUID()
        #expect(EnlaceVisita.visita(de: EnlaceVisita.url(id)) == id)
        #expect(EnlaceVisita.visita(de: try #require(URL(string: "rico://auth/confirmar"))) == nil)
    }

    // MARK: Plan gratis

    @Test func planGratisCapturaUnaVisitaAlMes() async throws {
        let primero = procesador()
        primero.limiteMensual = 1
        let resultadoPrimero = await primero.procesar(comercio: "TPV LA TRASTIENDA", importe: "35,00 €")
        #expect(resultadoPrimero.visita != nil)

        let segundo = procesador(ahora: ahora.addingTimeInterval(3600))
        segundo.limiteMensual = 1
        let resultadoSegundo = await segundo.procesar(comercio: "TPV CASA PEPE", importe: "20,00 €")

        #expect(resultadoSegundo == .limiteGratis)
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 1)
        #expect(notificador.avisos.count == 1)
    }

    @Test func capturaDescartadaNoGastaElMes() async throws {
        let primero = procesador()
        primero.limiteMensual = 1
        let borrador = try visita(await primero.procesar(comercio: "TPV LA TRASTIENDA", importe: "35,00 €").visita)
        try AccionesBandeja.descartar(borrador, en: contexto)

        let segundo = procesador(ahora: ahora.addingTimeInterval(3600))
        segundo.limiteMensual = 1
        let resultado = await segundo.procesar(comercio: "TPV CASA PEPE", importe: "20,00 €")

        #expect(resultado.visita != nil)
    }

    @Test func premiumNoTieneLimite() async throws {
        for (hora, comercio) in ["TPV LA TRASTIENDA", "TPV CASA PEPE", "TPV O GRELO"].enumerated() {
            let resultado = await procesador(ahora: ahora.addingTimeInterval(Double(hora) * 3600))
                .procesar(comercio: comercio, importe: "20,00 €")
            #expect(resultado.visita != nil)
        }
    }
}

// MARK: Estancias

@MainActor
final class BuscadorPuntosFalso: BuscadorPuntosCercanos {
    var lugares: [LugarEncontrado] = []
    private(set) var busquedas = 0

    func buscar(cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado] {
        busquedas += 1
        return lugares
    }
}

@MainActor
final class NotificadorEstanciasFalso: Notificador {
    private(set) var preguntas: [String] = []

    func programarValoracion(visitaID: UUID, sitio: String?, importe: Importe, retraso: TimeInterval) async {}
    func cancelar(visitaID: UUID) {}
    func programarEstancia(visitaID: UUID, sitio: String) async {
        preguntas.append(sitio)
    }
}

@MainActor
@Suite("Detección por ubicación")
struct EstanciasTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let buscador = BuscadorPuntosFalso()
    let notificador = NotificadorEstanciasFalso()
    let llegada = Date(timeIntervalSince1970: 1_790_000_000)
    let vigo = Coordenada(latitud: 42.2406, longitud: -8.7207)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    private func estancia(minutos: Double) -> Estancia {
        Estancia(
            latitud: vigo.latitud,
            longitud: vigo.longitud,
            llegada: llegada,
            salida: llegada.addingTimeInterval(minutos * 60),
            precisionMetros: 20
        )
    }

    private var procesador: ProcesadorEstancias {
        ProcesadorEstancias(contexto: contexto, buscador: buscador, notificador: notificador)
    }

    @Test func comidaLargaEnUnRestauranteCreaUnBorrador() async throws {
        buscador.lugares = [
            LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: vigo.latitud, longitud: vigo.longitud, categoria: FiltroSitios.Categoria.restaurante)
        ]

        let id = try #require(await procesador.procesar(estancia(minutos: 75)))

        let visitas = try contexto.fetch(FetchDescriptor<Visita>())
        #expect(visitas.map(\.id) == [id])
        #expect(visitas.first?.origen == .ubicacion)
        #expect(visitas.first?.estado == .borrador)
        #expect(visitas.first?.restaurante?.mapItemID == "I-GRELO")
        #expect(notificador.preguntas == ["Taberna O Grelo"])
    }

    @Test func estanciaCortaNoBuscaNada() async {
        #expect(await procesador.procesar(estancia(minutos: 15)) == nil)
        #expect(buscador.busquedas == 0)
    }

    @Test func supermercadoNoCuenta() async throws {
        buscador.lugares = [
            LugarEncontrado(mapItemID: "I-GADIS", nombre: "Gadis Supermercado", ciudad: "Vigo", latitud: vigo.latitud, longitud: vigo.longitud, categoria: FiltroSitios.Categoria.restaurante)
        ]

        #expect(await procesador.procesar(estancia(minutos: 60)) == nil)
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 0)
        #expect(notificador.preguntas.isEmpty)
    }

    @Test func comidaYaApuntadaNoPregunta() async throws {
        let apuntada = Visita(fecha: llegada.addingTimeInterval(20 * 60), origen: .manual)
        contexto.insert(apuntada)
        try contexto.save()

        #expect(await procesador.procesar(estancia(minutos: 90)) == nil)
        #expect(buscador.busquedas == 0)
    }
}
