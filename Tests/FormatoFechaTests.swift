import Foundation
import Testing
import Visitas

@Suite("FormatoFecha")
struct FormatoFechaTests {
    let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }()
    let locale = Locale(identifier: "es_ES")

    func fecha(_ a: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendario.date(from: DateComponents(year: a, month: m, day: d, hour: h, minute: min))!
    }

    /// Lunes 19 de octubre de 2026, 10:00.
    var ahora: Date { fecha(2026, 10, 19, 10) }

    func texto(_ f: Date) -> String {
        FormatoFecha.corta(f, ahora: ahora, calendario: calendario, locale: locale)
    }

    @Test func mismoDiaEsHoy() {
        #expect(texto(fecha(2026, 10, 19, 8)) == "Hoy")
    }

    @Test func diaAnteriorEsAyer() {
        #expect(texto(fecha(2026, 10, 18, 23, 30)) == "Ayer")
    }

    @Test func dentroDeLaSemanaEsElDia() {
        #expect(texto(fecha(2026, 10, 14, 12)).lowercased().contains("miércoles"))
    }

    @Test func hace7DiasNoEsDiaDeLaSemana() {
        let t = texto(fecha(2026, 10, 12, 21)).lowercased()
        #expect(t.contains("12"))
        #expect(!t.contains("lunes"))
    }

    @Test func otroAnoLlevaAno() {
        #expect(texto(fecha(2025, 3, 3, 12)).contains("2025"))
    }
}
