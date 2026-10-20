import Foundation
import Testing
@testable import RicoCore

@Suite("Importe")
struct ImporteTests {
    @Test(arguments: [
        ("48", 4800),
        ("48,5", 4850),
        ("48,50", 4850),
        ("48.50", 4850),
        ("1.234,56", 123456),
        ("1,234.56", 123456),
        ("1.234", 123400),
        ("12 €", 1200),
        ("0,99", 99)
    ])
    func leeLoQueEscribeElUsuario(texto: String, centimos: Int) {
        #expect(Importe(texto: texto)?.centimos == centimos)
    }

    @Test(arguments: ["", "abc", "-5"])
    func rechazaTextoNoValido(texto: String) {
        #expect(Importe(texto: texto) == nil)
    }

    @Test func porPersona() {
        let total = Importe(centimos: 4800)
        #expect(total.porPersona(comensales: 2, pagueTodo: true).centimos == 2400)
        #expect(total.porPersona(comensales: 3, pagueTodo: true).centimos == 1600)
        #expect(total.porPersona(comensales: 4, pagueTodo: false).centimos == 4800)
        #expect(total.porPersona(comensales: 0, pagueTodo: true).centimos == 4800)
    }
}

@Suite("Estrellas")
struct EstrellasTests {
    @Test func tocarPoneLaNotaYRepetirQuitaMedia() {
        #expect(Estrellas.alTocar(estrella: 4, actual: 0) == 4)
        #expect(Estrellas.alTocar(estrella: 4, actual: 4) == 3.5)
        #expect(Estrellas.alTocar(estrella: 4, actual: 3.5) == 4)
        #expect(Estrellas.alTocar(estrella: 1, actual: 1) == 0.5)
    }

    @Test func normaliza() {
        #expect(Estrellas.normalizar(4.3) == 4.5)
        #expect(Estrellas.normalizar(4.2) == 4)
        #expect(Estrellas.normalizar(0) == 0.5)
        #expect(Estrellas.normalizar(7) == 5)
    }

    @Test func relleno() {
        #expect(Estrellas.relleno(estrella: 4, nota: 4.5) == 1)
        #expect(Estrellas.relleno(estrella: 5, nota: 4.5) == 0.5)
        #expect(Estrellas.relleno(estrella: 5, nota: 4) == 0)
    }
}

@Suite("Filtro de pagos")
struct FiltroPagosTests {
    let ahora = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func ignoraImportesPequenos() {
        let pago = PagoEntrante(comercio: "CAFE MOLINO", importe: Importe(centimos: 180), fecha: ahora)
        #expect(FiltroPagos().evaluar(pago, recientes: []) == .ignorarImporte)
    }

    @Test func ignoraTarjetasNoVigiladas() {
        let filtro = FiltroPagos(tarjetasVigiladas: ["Personal"])
        let pago = PagoEntrante(comercio: "O GRELO", importe: Importe(centimos: 4800), fecha: ahora, tarjeta: "Empresa")
        #expect(filtro.evaluar(pago, recientes: []) == .ignorarTarjeta)
    }

    @Test func detectaElMismoPagoDosVeces() {
        let primero = PagoEntrante(comercio: "SQ *BAR O GRELO", importe: Importe(centimos: 4800), fecha: ahora)
        let segundo = PagoEntrante(comercio: "SQ *BAR O GRELO", importe: Importe(centimos: 4800), fecha: ahora.addingTimeInterval(90))
        let tarde = PagoEntrante(comercio: "SQ *BAR O GRELO", importe: Importe(centimos: 4800), fecha: ahora.addingTimeInterval(600))
        #expect(FiltroPagos().evaluar(segundo, recientes: [primero]) == .duplicado)
        #expect(FiltroPagos().evaluar(tarde, recientes: [primero]) == .aceptar)
    }
}
