import Foundation
import Testing
@testable import RicoCore

@Suite("Calculadora del resumen")
struct CalculadoraResumenTests {
    /// Zona horaria fija para que las pruebas no dependan de la máquina.
    let calendario = CalculadoraResumen.calendarioEspanol(zonaHoraria: TimeZone(secondsFromGMT: 3600)!)
    let grelo = UUID()
    let pepe = UUID()
    let lua = UUID()
    let mar = UUID()

    private func fecha(_ mes: Int, _ dia: Int, _ hora: Int = 14, _ minuto: Int = 0, ano: Int = 2026) -> Date {
        calendario.date(from: DateComponents(year: ano, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    private func visita(
        _ fecha: Date,
        sitio: UUID? = nil,
        nombre: String = "Taberna O Grelo",
        estrellas: Double? = 4,
        euros: Int? = nil,
        divisa: String = "EUR",
        comensales: Int = 1,
        valorada: Bool = true,
        ciudad: String? = nil,
        cocina: String? = nil,
        encanto: [String] = []
    ) -> VisitaResumible {
        VisitaResumible(
            fecha: fecha,
            valorada: valorada,
            estrellas: estrellas,
            importe: euros.map { Importe(centimos: $0 * 100, divisa: divisa) },
            comensales: comensales,
            restauranteID: sitio ?? grelo,
            restaurante: nombre,
            ciudad: ciudad,
            cocina: cocina,
            platosEncanto: encanto
        )
    }

    // MARK: Semanas

    @Test func semanasDeOctubreEmpiezanEnLunes() {
        // El 1 de octubre de 2026 es jueves.
        let semanas = CalculadoraResumen.resumen(de: [], mes: fecha(10, 15), calendario: calendario).semanas

        #expect(semanas.map(\.diaInicio) == [1, 5, 12, 19, 26])
        #expect(semanas.map(\.diaFin) == [4, 11, 18, 25, 31])
        #expect(semanas.allSatisfy { calendario.component(.weekday, from: $0.inicio) == 2 || $0.diaInicio == 1 })
    }

    @Test func mesQueEmpiezaEnLunes() {
        // El 1 de junio de 2026 es lunes.
        let semanas = CalculadoraResumen.semanas(de: fecha(6, 10), calendario: calendario)

        #expect(semanas.count == 5)
        #expect(semanas.map { calendario.component(.day, from: $0.start) } == [1, 8, 15, 22, 29])
    }

    @Test func gastoPorSemanasRespetaLaMedianoche() {
        let domingoNoche = visita(fecha(10, 4, 23, 30), euros: 20)
        let lunesMadrugada = visita(fecha(10, 5, 0, 30), euros: 30)
        let finDeMes = visita(fecha(10, 31, 22), euros: 10)

        let semanas = CalculadoraResumen.resumen(
            de: [domingoNoche, lunesMadrugada, finDeMes],
            mes: fecha(10, 1),
            calendario: calendario
        ).semanas

        #expect(semanas.map(\.gasto.centimos) == [2000, 3000, 0, 0, 1000])
        #expect(semanas.map(\.visitas) == [1, 1, 0, 0, 1])
    }

    // MARK: Cifras

    @Test func totalesDelMes() {
        let visitas = [
            visita(fecha(10, 2), estrellas: 4, euros: 30, comensales: 2),
            visita(fecha(10, 9), sitio: pepe, estrellas: 5, euros: 50),
            visita(fecha(10, 20), sitio: lua, estrellas: nil, euros: 20),
            visita(fecha(9, 30), euros: 999),
            visita(fecha(11, 1, 0, 10), euros: 999)
        ]

        let cifras = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario).cifras

        #expect(cifras.visitas == 3)
        #expect(cifras.gasto == Importe(centimos: 10000, divisa: "EUR"))
        // 15 + 50 + 20 entre 3 = 28,33
        #expect(cifras.gastoMedioPorPersona == Importe(centimos: 2833, divisa: "EUR"))
        #expect(cifras.notaMedia == 4.5)
    }

    @Test func excluyeVisitasSinValorar() {
        let visitas = [
            visita(fecha(10, 2), euros: 30),
            visita(fecha(10, 3), sitio: pepe, estrellas: nil, euros: 80, valorada: false, encanto: ["Croquetas"])
        ]

        let resumen = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario)

        #expect(resumen.cifras.visitas == 1)
        #expect(resumen.cifras.gasto?.centimos == 3000)
        #expect(resumen.cifras.sitiosNuevos == 1)
        #expect(resumen.mejoresSitios.map(\.nombre) == ["Taberna O Grelo"])
        #expect(resumen.platosEncanto.isEmpty)
    }

    @Test func monedasMezcladasSoloSumanLaPrincipal() {
        let visitas = [
            visita(fecha(10, 2), euros: 30),
            visita(fecha(10, 3), euros: 20),
            visita(fecha(10, 4), euros: 90, divisa: "USD")
        ]

        let resumen = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario)

        #expect(resumen.cifras.gasto == Importe(centimos: 5000, divisa: "EUR"))
        #expect(resumen.cifras.gastoMedioPorPersona == Importe(centimos: 2500, divisa: "EUR"))
        #expect(resumen.semanas.map(\.gasto.centimos).reduce(0, +) == 5000)
        #expect(resumen.divisa == "EUR")
    }

    @Test func monedaPrincipalPrefiereEurosEnEmpate() {
        #expect(Importe.monedaPrincipal(["USD", "EUR"]) == "EUR")
        #expect(Importe.monedaPrincipal(["USD", "GBP"]) == "GBP")
        #expect(Importe.monedaPrincipal(["USD", "USD", "EUR"]) == "USD")
        #expect(Importe.monedaPrincipal([]) == nil)
    }

    @Test func sitiosNuevosYRepetidos() {
        let visitas = [
            visita(fecha(9, 10)),
            visita(fecha(10, 2)),
            visita(fecha(10, 5), sitio: pepe, nombre: "Casa Pepe"),
            visita(fecha(10, 12), sitio: pepe, nombre: "Casa Pepe")
        ]

        let cifras = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario).cifras

        #expect(cifras.sitiosRepetidos == 1)
        #expect(cifras.sitiosNuevos == 1)
    }

    // MARK: Comparación

    @Test func comparaConElMesAnterior() {
        let visitas = [
            visita(fecha(9, 5), euros: 60),
            visita(fecha(9, 20), euros: 40),
            visita(fecha(10, 2), euros: 100),
            visita(fecha(10, 9), euros: 30),
            visita(fecha(10, 20), euros: 20)
        ]

        let resumen = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario)

        #expect(resumen.anterior.visitas == 2)
        #expect(resumen.comparacion.gasto == 0.5)
        #expect(resumen.comparacion.visitas == 1)
    }

    @Test func sinComparacionSiElMesAnteriorEstaVacio() {
        let resumen = CalculadoraResumen.resumen(de: [visita(fecha(10, 2), euros: 30)], mes: fecha(10, 15), calendario: calendario)

        #expect(resumen.comparacion.gasto == nil)
        #expect(resumen.comparacion.visitas == nil)
    }

    @Test func sinComparacionDeGastoEntreMonedasDistintas() {
        let visitas = [
            visita(fecha(9, 5), euros: 60, divisa: "USD"),
            visita(fecha(10, 2), euros: 100)
        ]

        let resumen = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario)

        #expect(resumen.comparacion.gasto == nil)
        #expect(resumen.comparacion.visitas == 0)
    }

    // MARK: Top del mes

    @Test func topPorNotaConEmpatesYLimite() {
        let visitas = [
            visita(fecha(10, 1), sitio: grelo, nombre: "Taberna O Grelo", estrellas: 4),
            visita(fecha(10, 2), sitio: pepe, nombre: "Casa Pepe", estrellas: 4.5),
            visita(fecha(10, 3), sitio: lua, nombre: "A Lúa", estrellas: 4.5),
            visita(fecha(10, 4), sitio: lua, nombre: "A Lúa", estrellas: 4.5),
            visita(fecha(10, 5), sitio: mar, nombre: "Mar de Vigo", estrellas: 3),
            visita(fecha(10, 6), sitio: UUID(), nombre: "Sin nota", estrellas: nil)
        ]

        let top = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario).mejoresSitios

        #expect(top.map(\.nombre) == ["A Lúa", "Casa Pepe", "Taberna O Grelo"])
        #expect(top.first?.visitas == 2)
        #expect(top.first?.restauranteID == lua)
    }

    @Test func platosQueTeEncantaronSinRepetir() {
        let visitas = [
            visita(fecha(10, 2), encanto: ["Pulpo á feira"]),
            visita(fecha(10, 9), encanto: ["pulpo á feira", "Filloas"]),
            visita(fecha(10, 10), sitio: pepe, nombre: "Casa Pepe", encanto: ["Pulpo á feira"])
        ]

        let platos = CalculadoraResumen.resumen(de: visitas, mes: fecha(10, 15), calendario: calendario).platosEncanto

        #expect(platos.map(\.nombre) == ["Pulpo á feira", "pulpo á feira", "Filloas"])
        #expect(platos.map(\.restaurante) == ["Casa Pepe", "Taberna O Grelo", "Taberna O Grelo"])
    }

    // MARK: Meses

    @Test func navegacionDeMeses() {
        let ahora = fecha(10, 21)

        #expect(CalculadoraResumen.puedeAvanzar(desde: fecha(9, 30), ahora: ahora, calendario: calendario))
        #expect(!CalculadoraResumen.puedeAvanzar(desde: fecha(10, 1), ahora: ahora, calendario: calendario))
        #expect(CalculadoraResumen.mes(fecha(1, 15), desplazado: -1, calendario: calendario) == fecha(12, 1, 0, ano: 2025))
        #expect(CalculadoraResumen.inicioMes(fecha(10, 31, 23, 59), calendario: calendario) == fecha(10, 1, 0))
    }

    @Test func ultimoMesConVisitas() {
        let visitas = [
            visita(fecha(6, 3)),
            visita(fecha(8, 20)),
            visita(fecha(9, 2), valorada: false)
        ]

        let ultimo = CalculadoraResumen.ultimoMesConVisitas(visitas, antesDe: fecha(10, 15), calendario: calendario)

        #expect(ultimo == fecha(8, 1, 0))
    }

    // MARK: Tu año

    @Test func resumenAnual() {
        let visitas = [
            visita(fecha(10, 31, ano: 2025), euros: 999, ciudad: "Vigo"),
            visita(fecha(11, 3, ano: 2025), euros: 40, ciudad: "Vigo", cocina: "Gallega"),
            visita(fecha(3, 3), euros: 60, ciudad: "Madrid", cocina: "Japonesa"),
            visita(fecha(3, 8), euros: 20, ciudad: "vigo", cocina: "gallega"),
            visita(fecha(10, 2), euros: 30, ciudad: "Madrid", cocina: "Japonesa"),
            visita(fecha(10, 3), euros: 15, divisa: "USD", ciudad: "Lisboa"),
            visita(fecha(10, 4), euros: 80, valorada: false, ciudad: "Oporto")
        ]

        let ano = CalculadoraResumen.resumenAnual(de: visitas, hasta: fecha(10, 15), calendario: calendario)

        #expect(ano.meses.count == 12)
        #expect(ano.meses.first?.mes == fecha(11, 1, 0, ano: 2025))
        #expect(ano.meses.last?.mes == fecha(10, 1, 0))
        #expect(ano.meses.map(\.gasto.centimos) == [4000, 0, 0, 0, 8000, 0, 0, 0, 0, 0, 0, 3000])
        #expect(ano.visitas == 5)
        #expect(ano.gasto == Importe(centimos: 15000, divisa: "EUR"))
        #expect(ano.porCocina.map(\.nombre) == ["Japonesa", "Gallega"])
        #expect(ano.porCocina.map(\.gasto.centimos) == [9000, 6000])
        #expect(ano.ciudades.map(\.nombre) == ["Madrid", "Vigo", "Lisboa"])
        #expect(ano.ciudades.map(\.visitas) == [2, 2, 1])
    }
}
