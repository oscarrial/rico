import SwiftUI
import Charts
import DesignSystem
import RicoCore

/// «Tu año en Rico»: evolución del gasto, ciudades y tipos de cocina de los últimos 12 meses.
/// Sin Premium se ve borroso, con un botón para desbloquearlo.
struct TuAnoView: View {
    let resumen: ResumenAnual
    let formato: FormatoResumen

    @Environment(\.esPremium) private var esPremium
    @Environment(\.pedirPremium) private var pedirPremium

    init(resumen: ResumenAnual, formato: FormatoResumen) {
        self.resumen = resumen
        self.formato = formato
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TituloSeccion(Text("Tu año en Rico", bundle: .module))
                Spacer()
                if !esPremium {
                    Label { Text("Premium", bundle: .module) } icon: { Image(systemName: "lock.fill") }
                        .font(.rico(.caption, peso: .heavy))
                        .foregroundStyle(Color.ricoTomateTexto)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.ricoTomateSuave, in: Capsule())
                        .accessibilityHidden(true)
                }
            }

            if esPremium {
                if resumen.estaVacio {
                    Tarjeta {
                        Text("No tienes visitas en estos 12 meses.", bundle: .module)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                } else {
                    contenido(resumen)
                }
            } else {
                ZStack {
                    // Tus propias cifras (o un ejemplo si aún no hay) detrás del cristal.
                    contenido(resumen.estaVacio ? Self.muestra(formato.calendario) : resumen)
                        .blur(radius: 9)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    bloqueo
                }
            }
        }
    }

    // MARK: Bloqueo

    private var bloqueo: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.rico(.title2, peso: .bold))
                .foregroundStyle(Color.ricoTinta)
                .accessibilityHidden(true)
            Text("Tu año en Rico, con Premium", bundle: .module)
                .font(.rico(.headline, peso: .heavy))
                .foregroundStyle(Color.ricoTinta)
                .multilineTextAlignment(.center)
            Text("Mira en qué cocinas gastas más, tus ciudades y cómo cambia tu gasto mes a mes.", bundle: .module)
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
            Button {
                pedirPremium()
            } label: {
                Text("Desbloquear con Premium", bundle: .module)
            }
            .buttonStyle(.ricoPrincipal)
            .padding(.top, 6)
        }
        .padding(20)
        .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        .overlay(RoundedRectangle(cornerRadius: Medidas.radioTarjeta).strokeBorder(Color.ricoLinea))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: Contenido

    private func contenido(_ resumen: ResumenAnual) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            evolucion(resumen)
            if !resumen.ciudades.isEmpty {
                lista(
                    titulo: Text("Tus ciudades", bundle: .module),
                    filas: resumen.ciudades.map { ciudad in
                        (nombre: ciudad.nombre, valor: String(AttributedString(localized: "^[\(ciudad.visitas) visita](inflect: true)", bundle: .module).characters))
                    }
                )
            }
            if !resumen.porCocina.isEmpty {
                lista(
                    titulo: Text("Gasto por tipo de cocina", bundle: .module),
                    filas: resumen.porCocina.map { cocina in (nombre: cocina.nombre, valor: cocina.gasto.textoMoneda) }
                )
            }
        }
    }

    private func evolucion(_ resumen: ResumenAnual) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Gasto en 12 meses", bundle: .module)
                    .font(.rico(.footnote, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
                Text(resumen.gasto.textoMoneda)
                    .font(.rico(.title2, peso: .black))
                    .foregroundStyle(Color.ricoTinta)
                Chart(resumen.meses) { mes in
                    BarMark(
                        x: .value(String(localized: "Mes", bundle: .module), formato.mesCorto(mes.mes)),
                        y: .value(String(localized: "Gasto", bundle: .module), mes.gasto.euros)
                    )
                    .foregroundStyle(Color.ricoTomate)
                    .cornerRadius(4)
                    .accessibilityLabel(Text(formato.mesYAno(mes.mes)))
                    .accessibilityValue(Text("\(mes.gasto.textoMoneda), ^[\(mes.visitas) visita](inflect: true)", bundle: .module))
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.rico(.caption2, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.ricoLinea)
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.Currency(code: resumen.divisa).precision(.fractionLength(0)))
                            .font(.rico(.caption2, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
                .frame(height: 170)
            }
        }
    }

    private func lista(titulo: Text, filas: [(nombre: String, valor: String)]) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                titulo
                    .font(.rico(.footnote, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
                ForEach(Array(filas.enumerated()), id: \.offset) { _, fila in
                    HStack(alignment: .firstTextBaseline) {
                        Text(fila.nombre)
                            .font(.rico(.body, peso: .bold))
                            .foregroundStyle(Color.ricoTinta)
                        Spacer(minLength: 8)
                        Text(fila.valor)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Ejemplo

    /// Datos de ejemplo para el reclamo cuando aún no hay visitas en el año. Nunca se ven nítidos.
    static func muestra(_ calendario: Calendar) -> ResumenAnual {
        let ahora = Date.now
        let sitios: [(ciudad: String, cocina: String, euros: Int)] = [
            ("Madrid", "Japonesa", 42), ("Vigo", "Gallega", 35), ("Madrid", "Italiana", 28),
            ("Barcelona", "Mediterránea", 55), ("Vigo", "Gallega", 30), ("Madrid", "Japonesa", 38)
        ]
        let visitas = (0..<12).flatMap { atras in
            let mes = CalculadoraResumen.mes(ahora, desplazado: -atras, calendario: calendario)
            return (0..<(1 + atras % 3)).map { indice in
                let sitio = sitios[(atras + indice) % sitios.count]
                return VisitaResumible(
                    fecha: calendario.date(byAdding: .day, value: 3 + indice * 7, to: mes) ?? mes,
                    importe: Importe(centimos: sitio.euros * 100),
                    ciudad: sitio.ciudad,
                    cocina: sitio.cocina
                )
            }
        }
        return CalculadoraResumen.resumenAnual(de: visitas, hasta: ahora, calendario: calendario)
    }
}
