import Foundation
import RicoCore

extension Importe {
    /// «48,00 €» según el idioma del usuario.
    var textoMoneda: String {
        decimal.formatted(.currency(code: divisa))
    }

    /// «48,00» para rellenar el campo de importe.
    var textoEditable: String {
        decimal.formatted(.number.precision(.fractionLength(2)))
    }
}

enum FormatoFecha {
    /// «Hoy», «Ayer», «jueves» o «11 oct».
    static func corta(_ fecha: Date, ahora: Date = .now, calendario: Calendar = .current) -> String {
        if calendario.isDateInToday(fecha) { return String(localized: "Hoy", bundle: .module) }
        if calendario.isDateInYesterday(fecha) { return String(localized: "Ayer", bundle: .module) }
        if let dias = calendario.dateComponents([.day], from: fecha, to: ahora).day, dias < 7, dias >= 0 {
            return fecha.formatted(.dateTime.weekday(.wide))
        }
        if calendario.isDate(fecha, equalTo: ahora, toGranularity: .year) {
            return fecha.formatted(.dateTime.day().month(.abbreviated))
        }
        return fecha.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// «Octubre de 2026», para agrupar el diario.
    static func mes(_ fecha: Date) -> String {
        fecha.formatted(.dateTime.month(.wide).year())
    }
}

extension String {
    var recortado: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilSiVacio: String? { recortado.isEmpty ? nil : recortado }
}

extension UUID {
    /// Número estable para elegir un color de relleno.
    var semilla: Int { uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }
}
