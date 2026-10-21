import Foundation
import SwiftData
import Testing
import Modelos
import RicoCore
import Visitas

@MainActor
@Suite("Ficha rápida")
struct FichaRapidaTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let grelo = LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: 42.2406, longitud: -8.7207)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    @Test func guardarCreaRestauranteYVisitaValorada() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4.5
        modelo.importeTexto = "48,00"
        modelo.comensales = 2
        modelo.volveria = .si
        modelo.platos = [
            BorradorPlato(nombre: "Pulpo á feira", valoracion: .encanto),
            BorradorPlato(nombre: "   ")
        ]

        let visita = try modelo.guardar(en: contexto)

        #expect(visita.estado == .valorada)
        #expect(visita.origen == .manual)
        #expect(visita.estrellas == 4.5)
        #expect(visita.importePorPersona?.centimos == 2400)
        #expect(visita.platos?.count == 1)
        #expect(visita.restaurante?.mapItemID == "I-GRELO")
        #expect(try contexto.fetchCount(FetchDescriptor<Restaurante>()) == 1)
    }

    @Test func sinEstrellasNoSeGuarda() {
        let modelo = FichaRapidaModelo(lugar: grelo)
        #expect(!modelo.puedeGuardar)
        #expect(throws: ErrorFicha.sinNota) { try modelo.guardar(en: contexto) }
    }

    @Test func segundaVisitaReutilizaElRestaurante() throws {
        for nota in [4.0, 5.0] {
            let modelo = FichaRapidaModelo(lugar: grelo)
            modelo.estrellas = nota
            try modelo.guardar(en: contexto)
        }
        let restaurantes = try contexto.fetch(FetchDescriptor<Restaurante>())
        #expect(restaurantes.count == 1)
        #expect(restaurantes.first?.visitas?.count == 2)
    }

    @Test func editarReemplazaPlatosYConservaFotos() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4
        modelo.platos = [BorradorPlato(nombre: "Zamburiñas", valoracion: .bien)]
        modelo.anadirFoto(BorradorFoto(miniatura: Data([1]), datos: Data([1, 2]), fecha: .now))
        let visita = try modelo.guardar(en: contexto)

        let edicion = FichaRapidaModelo(visita: visita)
        #expect(edicion.importeTexto.isEmpty)
        #expect(edicion.fotos.count == 1)
        edicion.platos[0].valoracion = .noRepetiria
        edicion.platos.append(BorradorPlato(nombre: "Tortilla", valoracion: .encanto))
        try edicion.guardar(en: contexto)

        #expect(visita.platosOrdenados.map(\.nombre) == ["Zamburiñas", "Tortilla"])
        #expect(visita.platosOrdenados.first?.valoracion == .noRepetiria)
        #expect(visita.fotos?.count == 1)
        #expect(try contexto.fetchCount(FetchDescriptor<Plato>()) == 2)
    }

    @Test func altaAManoCreaRestauranteSinCoordenadas() throws {
        let modelo = FichaRapidaModelo(manual: RestauranteManual(nombre: "  Casa Manolo ", ciudad: "Ourense"))
        #expect(modelo.nombreRestaurante == "Casa Manolo")
        #expect(modelo.lugarTexto == "Ourense")
        modelo.estrellas = 4
        let visita = try modelo.guardar(en: contexto)

        let restaurante = try #require(visita.restaurante)
        #expect(restaurante.nombre == "Casa Manolo")
        #expect(restaurante.ciudad == "Ourense")
        #expect(restaurante.latitud == nil)
        #expect(restaurante.mapItemID == nil)
    }

    @Test func altaAManoReutilizaElMismoRestaurante() throws {
        for (nombre, ciudad) in [("Casa Manolo", "Ourense"), ("casa manolo", "OURENSE")] {
            let modelo = FichaRapidaModelo(manual: RestauranteManual(nombre: nombre, ciudad: ciudad))
            modelo.estrellas = 4
            try modelo.guardar(en: contexto)
        }
        let otro = FichaRapidaModelo(manual: RestauranteManual(nombre: "Casa Manolo", ciudad: "Lugo"))
        otro.estrellas = 3
        try otro.guardar(en: contexto)

        let restaurantes = try contexto.fetch(FetchDescriptor<Restaurante>())
        #expect(restaurantes.count == 2)
        #expect(restaurantes.first { $0.ciudad == "Ourense" }?.visitas?.count == 2)
    }

    @Test func editarConservaLaMoneda() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4
        let visita = try modelo.guardar(en: contexto)
        visita.divisa = "USD"
        visita.importeCentimos = 2500
        try contexto.save()

        let edicion = FichaRapidaModelo(visita: visita)
        edicion.estrellas = 3
        try edicion.guardar(en: contexto)

        #expect(visita.divisa == "USD")
        #expect(visita.importeCentimos == 2500)
    }

    @Test func editarConservaLosMismosPlatos() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4
        modelo.platos = [
            BorradorPlato(nombre: "Zamburiñas", valoracion: .bien),
            BorradorPlato(nombre: "Tortilla", valoracion: .encanto)
        ]
        let visita = try modelo.guardar(en: contexto)
        let ids = visita.platosOrdenados.map(\.persistentModelID)

        let edicion = FichaRapidaModelo(visita: visita)
        edicion.platos[0].valoracion = .noRepetiria
        try edicion.guardar(en: contexto)

        #expect(visita.platosOrdenados.map(\.persistentModelID) == ids)
        #expect(visita.platosOrdenados.first?.valoracion == .noRepetiria)
    }

    @Test func quitarUnPlatoSoloBorraEse() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4
        modelo.platos = [
            BorradorPlato(nombre: "Zamburiñas", valoracion: .bien),
            BorradorPlato(nombre: "Tortilla", valoracion: .encanto)
        ]
        let visita = try modelo.guardar(en: contexto)

        let edicion = FichaRapidaModelo(visita: visita)
        edicion.quitarPlato(edicion.platos[1].id)
        try edicion.guardar(en: contexto)

        #expect(visita.platosOrdenados.map(\.nombre) == ["Zamburiñas"])
        #expect(try contexto.fetchCount(FetchDescriptor<Plato>()) == 1)
    }

    @Test func editarNoBorraFotosSinMiniatura() throws {
        let modelo = FichaRapidaModelo(lugar: grelo)
        modelo.estrellas = 4
        let visita = try modelo.guardar(en: contexto)

        let foto = Foto(datos: Data([1]), miniatura: nil)
        contexto.insert(foto)
        foto.visita = visita
        try contexto.save()
        let antes = visita.fotos?.count

        let edicion = FichaRapidaModelo(visita: visita)
        edicion.estrellas = 5
        try edicion.guardar(en: contexto)

        #expect(antes == 1)
        #expect(visita.fotos?.count == antes)
    }

    @Test func limiteDeTresFotosEnElPlanGratis() {
        let modelo = FichaRapidaModelo(lugar: grelo)
        for _ in 0..<4 {
            modelo.anadirFoto(BorradorFoto(miniatura: Data([0]), datos: Data([0]), fecha: .now))
        }
        #expect(modelo.fotos.count == LimitesGratis.fotosPorVisita)
        #expect(modelo.fotosRestantes == 0)
    }

    @Test func noRepiteLaMismaFotoDelCarrete() {
        let modelo = FichaRapidaModelo(lugar: grelo)
        let foto = BorradorFoto(miniatura: Data([0]), datos: Data([0]), fecha: .now, identificadorCarrete: "ABC")
        #expect(modelo.anadirFoto(foto))
        #expect(!modelo.anadirFoto(BorradorFoto(miniatura: Data([0]), datos: Data([0]), fecha: .now, identificadorCarrete: "ABC")))
    }
}
