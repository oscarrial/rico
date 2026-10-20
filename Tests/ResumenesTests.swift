import Foundation
import SwiftData
import Testing
import Modelos
import RicoCore
import Visitas

@MainActor
@Suite("Resúmenes")
struct ResumenesTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let calendario = Calendar(identifier: .gregorian)
    let grelo = LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: 42.2406, longitud: -8.7207)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    private func fecha(_ mes: Int, _ dia: Int) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: 12))!
    }

    @discardableResult
    private func visita(
        fecha: Date,
        estrellas: Double = 4,
        importe: String = "",
        platos: [BorradorPlato] = []
    ) throws -> Visita {
        let modelo = FichaRapidaModelo(lugar: grelo, fecha: fecha)
        modelo.estrellas = estrellas
        modelo.importeTexto = importe
        modelo.platos = platos
        return try modelo.guardar(en: contexto)
    }

    @Test func agrupaPorMesManteniendoElOrden() throws {
        let a = try visita(fecha: fecha(10, 20))
        let b = try visita(fecha: fecha(10, 5))
        let c = try visita(fecha: fecha(9, 12))

        let secciones = AgrupadorDiario.secciones([a, b, c])

        #expect(secciones.count == 2)
        #expect(secciones.map { $0.visitas.count } == [2, 1])
        #expect(secciones[0].visitas.map(\.id) == [a.id, b.id])
        #expect(secciones[1].visitas.map(\.id) == [c.id])
    }

    @Test func buscaEnPlatosSinDistinguirMayusculas() throws {
        let v = try visita(fecha: fecha(10, 5), platos: [BorradorPlato(nombre: "Pulpo á feira", valoracion: .encanto)])

        #expect(AgrupadorDiario.filtrar([v], busqueda: "pulpo").count == 1)
        #expect(AgrupadorDiario.filtrar([v], busqueda: "zzz").isEmpty)
    }

    @Test func notaYGastoMedio() throws {
        try visita(fecha: fecha(10, 5), estrellas: 4, importe: "24,00")
        try visita(fecha: fecha(10, 6), estrellas: 5, importe: "25,00")
        let restaurante = try #require(try contexto.fetch(FetchDescriptor<Restaurante>()).first)

        let resumen = ResumenRestaurante(restaurante: restaurante)

        #expect(resumen.notaMedia == 4.5)
        #expect(resumen.gastoMedioPorPersona?.centimos == 2450)
        #expect(resumen.gastoMedioPorPersona?.divisa == "EUR")
        #expect(resumen.visitas.count == 2)
    }

    @Test func gastoMedioIgnoraOtraMoneda() throws {
        try visita(fecha: fecha(10, 5), importe: "24,00")
        try visita(fecha: fecha(10, 6), importe: "25,00")
        let dolares = try visita(fecha: fecha(10, 7))
        dolares.divisa = "USD"
        dolares.importeCentimos = 9000
        try contexto.save()
        let restaurante = try #require(try contexto.fetch(FetchDescriptor<Restaurante>()).first)

        let resumen = ResumenRestaurante(restaurante: restaurante)

        #expect(resumen.gastoMedioPorPersona?.centimos == 2450)
        #expect(resumen.gastoMedioPorPersona?.divisa == "EUR")
    }

    @Test func platosAgrupadosConLaUltimaValoracion() throws {
        try visita(fecha: fecha(8, 1), platos: [BorradorPlato(nombre: "Pulpo", valoracion: .bien)])
        try visita(fecha: fecha(9, 1), platos: [BorradorPlato(nombre: "pulpo", valoracion: .noRepetiria)])
        try visita(fecha: fecha(10, 1), platos: [BorradorPlato(nombre: "Pulpo", valoracion: .encanto)])
        let restaurante = try #require(try contexto.fetch(FetchDescriptor<Restaurante>()).first)

        let resumen = ResumenRestaurante(restaurante: restaurante)

        #expect(resumen.platos.count == 1)
        #expect(resumen.platos.first?.veces == 3)
        #expect(resumen.platos.first?.ultimaValoracion == .encanto)
    }

    @Test func resumenDelMesSoloCuentaEsteMes() throws {
        let esteMes = try visita(fecha: fecha(10, 5), importe: "30,00")
        let mesPasado = try visita(fecha: fecha(9, 20), importe: "50,00")

        let resumen = AgrupadorDiario.resumenMes([esteMes, mesPasado], ahora: fecha(10, 20), calendario: calendario)

        #expect(resumen.visitas == 1)
        #expect(resumen.gasto.centimos == 3000)
        #expect(resumen.gasto.divisa == "EUR")
    }
}
