import Foundation
import SwiftData
import Testing
import Estadisticas
import Modelos
import RicoCore
import Visitas

/// Paso de las visitas de SwiftData a la calculadora del resumen (la lógica se prueba en RicoCore).
@MainActor
@Suite("Resumen del mes")
struct ResumenMesTests {
    let contenedor: ModelContainer
    let contexto: ModelContext
    let calendario = CalculadoraResumen.calendarioEspanol(zonaHoraria: TimeZone(secondsFromGMT: 3600)!)
    let grelo = LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: 42.2406, longitud: -8.7207)

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
    }

    private func fecha(_ mes: Int, _ dia: Int) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: 14))!
    }

    @Test func copiaLoQueNecesitaElResumen() throws {
        let modelo = FichaRapidaModelo(lugar: grelo, fecha: fecha(10, 5))
        modelo.estrellas = 4.5
        modelo.importeTexto = "48,00"
        modelo.platos = [
            BorradorPlato(nombre: "Pulpo á feira", valoracion: .encanto),
            BorradorPlato(nombre: "Pan", valoracion: .bien)
        ]
        let visita = try modelo.guardar(en: contexto)

        let resumible = VisitaResumible(visita)

        #expect(resumible.valorada)
        #expect(resumible.estrellas == 4.5)
        #expect(resumible.importe == Importe(centimos: 4800, divisa: "EUR"))
        #expect(resumible.restaurante == "Taberna O Grelo")
        #expect(resumible.restauranteID == visita.restaurante?.id)
        #expect(resumible.ciudad == "Vigo")
        #expect(resumible.platosEncanto == ["Pulpo á feira"])
    }

    @Test func losBorradoresNoCuentan() throws {
        let modelo = FichaRapidaModelo(lugar: grelo, fecha: fecha(10, 5))
        modelo.estrellas = 4
        modelo.importeTexto = "30,00"
        let valorada = try modelo.guardar(en: contexto)

        let borrador = Visita(fecha: fecha(10, 6), origen: .pago)
        borrador.importeCentimos = 9000
        contexto.insert(borrador)
        try contexto.save()

        let resumen = CalculadoraResumen.resumen(
            de: [valorada, borrador].map { VisitaResumible($0) },
            mes: fecha(10, 15),
            calendario: calendario
        )

        #expect(resumen.cifras.visitas == 1)
        #expect(resumen.cifras.gasto?.centimos == 3000)
    }
}
