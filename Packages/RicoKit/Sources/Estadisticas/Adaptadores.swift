import Foundation
import Modelos
import RicoCore

public extension VisitaResumible {
    /// Copia de una visita de SwiftData con lo que necesita el resumen.
    @MainActor
    init(_ visita: Visita) {
        self.init(
            id: visita.id,
            fecha: visita.fecha,
            valorada: visita.estado == .valorada,
            estrellas: visita.estrellas,
            importe: visita.importe,
            comensales: visita.comensales,
            pagueTodo: visita.pagueTodo,
            restauranteID: visita.restaurante?.id,
            restaurante: visita.restaurante?.nombre ?? "",
            ciudad: visita.restaurante?.ciudad,
            cocina: visita.restaurante?.cocina,
            platosEncanto: visita.platosOrdenados
                .filter { $0.valoracion == .encanto }
                .map(\.nombre)
        )
    }
}

extension Importe {
    /// «48,00 €» según el idioma del usuario.
    var textoMoneda: String {
        decimal.formatted(.currency(code: divisa))
    }

    /// Para los ejes de los gráficos.
    var euros: Double {
        Double(centimos) / 100
    }
}

/// Fechas del resumen, en el calendario del resumen.
struct FormatoResumen {
    let calendario: Calendar

    private var estilo: Date.FormatStyle {
        Date.FormatStyle(date: nil, time: nil, locale: .current, calendar: calendario, timeZone: calendario.timeZone)
    }

    /// «octubre de 2026».
    func mesYAno(_ fecha: Date) -> String {
        fecha.formatted(estilo.month(.wide).year())
    }

    /// «septiembre».
    func mes(_ fecha: Date) -> String {
        fecha.formatted(estilo.month(.wide))
    }

    /// «oct».
    func mesCorto(_ fecha: Date) -> String {
        fecha.formatted(estilo.month(.abbreviated))
    }
}
