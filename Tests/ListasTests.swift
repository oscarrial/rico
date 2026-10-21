import Foundation
import SwiftData
import Testing
import Modelos
import RicoCore

@MainActor
@Suite("Listas")
struct ListasTests {
    let contenedor: ModelContainer
    let contexto: ModelContext

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    private func numeroDeListas() throws -> Int {
        try contexto.fetchCount(FetchDescriptor<Lista>())
    }

    @Test func quieroProbarSeCreaUnaSolaVez() throws {
        let primera = try contexto.listaQuieroProbar()
        let segunda = try contexto.listaQuieroProbar()

        #expect(primera.id == segunda.id)
        #expect(primera.tipo == .quieroProbar)
        #expect(try numeroDeListas() == 1)
        #expect(try contexto.listasPropias().isEmpty)
    }

    @Test func gratisPermiteTresListasPropias() throws {
        for nombre in ["Cenas", "Con niños", "De viaje"] {
            try contexto.crearLista(nombre: nombre, esPremium: false)
        }
        #expect(try !contexto.puedeCrearListaPropia(esPremium: false))
        #expect(throws: ErrorListas.limiteGratis) {
            try contexto.crearLista(nombre: "Una más", esPremium: false)
        }
        #expect(try contexto.listasPropias().count == LimitesGratis.listasPropias)
    }

    @Test func quieroProbarNoCuentaParaElLimite() throws {
        _ = try contexto.listaQuieroProbar()
        for nombre in ["Cenas", "Con niños", "De viaje"] {
            try contexto.crearLista(nombre: nombre, esPremium: false)
        }
        #expect(try contexto.listasPropias().count == 3)
    }

    @Test func premiumNoTieneLimite() throws {
        for posicion in 0..<5 {
            try contexto.crearLista(nombre: "Lista \(posicion)", esPremium: true)
        }
        let propias = try contexto.listasPropias()
        #expect(propias.count == 5)
        #expect(propias.map(\.orden) == [0, 1, 2, 3, 4])
        #expect(try contexto.puedeCrearListaPropia(esPremium: true))
    }

    @Test func nombreVacioNoSeGuarda() {
        #expect(throws: ErrorListas.sinNombre) {
            try contexto.crearLista(nombre: "   ", esPremium: false)
        }
    }

    @Test func anadirDosVecesNoDuplica() throws {
        let restaurante = Restaurante(nombre: "Taberna O Grelo")
        contexto.insert(restaurante)
        let lista = try contexto.listaQuieroProbar()

        try contexto.anadir(restaurante, a: lista)
        try contexto.anadir(restaurante, a: lista)

        #expect(lista.restaurantes?.count == 1)
        #expect(lista.contiene(restaurante))
        #expect(restaurante.listas?.count == 1)

        try contexto.quitar(restaurante, de: lista)
        #expect(lista.restaurantes?.isEmpty == true)
        #expect(!lista.contiene(restaurante))
    }

    @Test func borrarListaNoBorraRestaurantes() throws {
        let restaurante = Restaurante(nombre: "Casa Marcelo")
        contexto.insert(restaurante)
        let lista = try contexto.crearLista(nombre: "Cenas especiales", emoji: "🍷", esPremium: false)
        try contexto.anadir(restaurante, a: lista)

        try contexto.borrar(lista)

        #expect(try contexto.listasPropias().isEmpty)
        let restaurantes = try contexto.fetch(FetchDescriptor<Restaurante>())
        #expect(restaurantes.count == 1)
        #expect(restaurantes.first?.listas?.isEmpty ?? true)
    }

    @Test func quieroProbarNoSeBorraNiRenombra() throws {
        let lista = try contexto.listaQuieroProbar()
        #expect(throws: ErrorListas.listaFija) { try contexto.borrar(lista) }
        #expect(throws: ErrorListas.listaFija) { try contexto.renombrar(lista, nombre: "Otra", emoji: nil) }
        #expect(try numeroDeListas() == 1)
    }

    @Test func ordenarGuardaLaPosicion() throws {
        let a = try contexto.crearLista(nombre: "A", esPremium: false)
        let b = try contexto.crearLista(nombre: "B", esPremium: false)
        let c = try contexto.crearLista(nombre: "C", esPremium: false)

        try contexto.ordenar([c, a, b])

        #expect(try contexto.listasPropias().map(\.nombre) == ["C", "A", "B"])
    }
}
