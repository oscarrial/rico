import Foundation
import RicoCore

extension Importe {
    /// «48,00 €» según el idioma del usuario.
    var textoMoneda: String {
        decimal.formatted(.currency(code: divisa))
    }

    /// «48,00» para rellenar el campo de importe.
    var textoEditable: String {
        decimal.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }
}

public enum FormatoFecha {
    /// «Hoy», «Ayer», «jueves» o «11 oct». Compara días de calendario, no periodos de 24 horas.
    public static func corta(
        _ fecha: Date,
        ahora: Date = .now,
        calendario: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let dias = calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: fecha),
            to: calendario.startOfDay(for: ahora)
        ).day ?? 0
        let estilo = Date.FormatStyle(
            date: nil,
            time: nil,
            locale: locale,
            calendar: calendario,
            timeZone: calendario.timeZone
        )
        if dias == 0 { return String(localized: "Hoy", bundle: .module) }
        if dias == 1 { return String(localized: "Ayer", bundle: .module) }
        if (2...6).contains(dias) {
            return fecha.formatted(estilo.weekday(.wide))
        }
        if calendario.isDate(fecha, equalTo: ahora, toGranularity: .year) {
            return fecha.formatted(estilo.day().month(.abbreviated))
        }
        return fecha.formatted(estilo.day().month(.abbreviated).year())
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
