import Foundation
import SwiftData
import Testing
import Mapa
import Modelos
import RicoCore
import Visitas

@MainActor
@Suite("Mapa")
struct MapaTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let grelo = LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: 42.2406, longitud: -8.7207)
    let marisqueria = LugarEncontrado(mapItemID: "I-MAR", nombre: "Marisquería Puerto", ciudad: "Vigo", latitud: 42.2380, longitud: -8.7260)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    @discardableResult
    private func visita(_ lugar: LugarEncontrado, estrellas: Double) throws -> Visita {
        let modelo = FichaRapidaModelo(lugar: lugar)
        modelo.estrellas = estrellas
        return try modelo.guardar(en: contexto)
    }

    private func restaurantes() throws -> [Restaurante] {
        try contexto.fetch(FetchDescriptor<Restaurante>())
    }

    private func pines() throws -> [PinRestaurante] {
        let listas = try contexto.fetch(FetchDescriptor<Lista>())
        return SitiosMapa.pines(try restaurantes(), quieroProbar: SitiosMapa.idsQuieroProbar(listas))
    }

    // MARK: Color por nota

    @Test(arguments: [
        (5.0, CategoriaPin.top),
        (4.5, .top),
        (4.46, .top),
        (4.4, .bien),
        (4.0, .bien),
        (3.5, .bien),
        (3.4, .normal),
        (1.0, .normal)
    ])
    func categoriaPorNota(nota: Double, esperada: CategoriaPin) {
        #expect(CategoriaPin.porNota(nota) == esperada)
    }

    // MARK: Qué sale en el mapa

    @Test func saleConVisitaValoradaYCoordenadas() throws {
        try visita(grelo, estrellas: 4)
        try visita(grelo, estrellas: 5)

        let resultado = try pines()

        #expect(resultado.count == 1)
        #expect(resultado.first?.nota == 4.5)
        #expect(resultado.first?.categoria == .top)
    }

    @Test func noSalenLosDadosDeAltaAMano() throws {
        let modelo = FichaRapidaModelo(manual: RestauranteManual(nombre: "Casa Pepe", ciudad: "Lugo"))
        modelo.estrellas = 4
        try modelo.guardar(en: contexto)

        #expect(try pines().isEmpty)
    }

    @Test func noSalenLosQueSoloTienenBorradores() throws {
        let restaurante = try contexto.restaurante(para: grelo)
        let borrador = Visita()
        contexto.insert(borrador)
        borrador.restaurante = restaurante
        try contexto.save()

        #expect(try pines().isEmpty)
    }

    @Test func quieroProbarSinVisitasSaleConPinPropio() throws {
        try contexto.anadirAQuieroProbar(marisqueria)

        let resultado = try pines()

        #expect(resultado.count == 1)
        #expect(resultado.first?.categoria == .quieroProbar)
        #expect(resultado.first?.nota == nil)
    }

    @Test func quieroProbarConVisitaSaleConSuNota() throws {
        try contexto.anadirAQuieroProbar(grelo)
        try visita(grelo, estrellas: 3)

        let resultado = try pines()

        #expect(resultado.count == 1)
        #expect(resultado.first?.categoria == .normal)
    }

    // MARK: Quiero probar

    @Test func anadirAQuieroProbarCreaLaListaYNoDuplica() throws {
        let primero = try contexto.anadirAQuieroProbar(grelo)
        let segundo = try contexto.anadirAQuieroProbar(grelo)

        #expect(primero.anadido)
        #expect(!segundo.anadido)
        #expect(primero.restaurante.id == segundo.restaurante.id)

        let listas = try contexto.fetch(FetchDescriptor<Lista>())
        #expect(listas.count == 1)
        #expect(listas.first?.tipo == .quieroProbar)
        #expect(listas.first?.restaurantes?.count == 1)
        #expect(try restaurantes().count == 1)
    }

    @Test func quieroProbarReutilizaElRestauranteYLaListaExistentes() throws {
        let existente = Lista(nombre: "Pendientes", tipo: .quieroProbar)
        contexto.insert(existente)
        try contexto.save()
        try visita(grelo, estrellas: 4)

        try contexto.anadirAQuieroProbar(grelo)

        let listas = try contexto.fetch(FetchDescriptor<Lista>())
        #expect(listas.count == 1)
        #expect(existente.restaurantes?.count == 1)
        #expect(try restaurantes().count == 1)
    }

    // MARK: Explorar zona

    @Test func exploradorGuardaLosResultadosSinRepetir() async throws {
        let falso = BuscadorCercanosFalso(resultado: .success([grelo, marisqueria, grelo]))
        let explorador = ExploradorZona(buscador: falso)
        let zona = ZonaMapa(latitud: 42.24, longitud: -8.72, latitudDelta: 0.02, longitudDelta: 0.02)

        await explorador.explorar(zona)

        #expect(explorador.estado == .listo)
        #expect(explorador.lugares.map(\.nombre) == ["Taberna O Grelo", "Marisquería Puerto"])
        #expect(explorador.zonaBuscada == zona)
        #expect(falso.zonasPedidas == [zona])
    }

    @Test func exploradorAvisaSiFallaYLimpiaAlSalir() async throws {
        let explorador = ExploradorZona(buscador: BuscadorCercanosFalso(resultado: .failure(ErrorFalso.sinRed)))
        let zona = ZonaMapa(latitud: 42.24, longitud: -8.72, latitudDelta: 0.02, longitudDelta: 0.02)

        await explorador.explorar(zona)
        #expect(explorador.estado == .error)
        #expect(explorador.lugares.isEmpty)

        explorador.limpiar()
        #expect(explorador.estado == .inactivo)
        #expect(explorador.zonaBuscada == nil)
    }

    @Test func explorarNoRepiteTusSitios() throws {
        try visita(grelo, estrellas: 4)
        // Mismo sitio sin identificador de Apple Maps (iOS 17), a pocos metros.
        let mismoSinID = LugarEncontrado(nombre: "taberna o grelo", latitud: 42.2407, longitud: -8.7208)
        // Mismo nombre pero en otra ciudad: es otro sitio.
        let otraCiudad = LugarEncontrado(nombre: "Taberna O Grelo", latitud: 43.3623, longitud: -8.4115)

        let visibles = SitiosMapa.sinRepetir([grelo, mismoSinID, marisqueria, otraCiudad], pines: try pines())

        #expect(visibles.map(\.id) == [marisqueria.id, otraCiudad.id])
    }

    // MARK: Encuadre

    @Test func encuadraTodosLosPuntos() throws {
        let zona = try #require(ZonaMapa.encuadrando([
            (latitud: 42.0, longitud: -8.0),
            (latitud: 43.0, longitud: -9.0)
        ]))

        #expect(abs(zona.latitud - 42.5) < 0.0001)
        #expect(abs(zona.longitud - (-8.5)) < 0.0001)
        #expect(zona.latitudDelta >= 1.0)
        #expect(zona.longitudDelta >= 1.0)
    }

    @Test func encuadreDeUnSoloPuntoTieneTamanoMinimo() throws {
        let zona = try #require(ZonaMapa.encuadrando([(latitud: 42.24, longitud: -8.72)]))
        #expect(zona.latitudDelta == 0.01)
        #expect(ZonaMapa.encuadrando([]) == nil)
    }

    @Test func laBusquedaCercanaSeLimitaAlCentro() {
        let ciudad = ZonaMapa(latitud: 40.4, longitud: -3.7, latitudDelta: 1.0, longitudDelta: 1.2)
        let limitada = ciudad.limitada(a: 0.08)
        #expect(limitada.latitud == 40.4)
        #expect(limitada.latitudDelta == 0.08)
        #expect(limitada.longitudDelta == 0.08)
    }
}

private enum ErrorFalso: Error {
    case sinRed
}

@MainActor
private final class BuscadorCercanosFalso: BuscadorCercanos {
    let resultado: Result<[LugarEncontrado], ErrorFalso>
    private(set) var zonasPedidas: [ZonaMapa] = []

    init(resultado: Result<[LugarEncontrado], ErrorFalso>) {
        self.resultado = resultado
    }

    func buscar(en zona: ZonaMapa) async throws -> [LugarEncontrado] {
        zonasPedidas.append(zona)
        return try resultado.get()
    }
}
