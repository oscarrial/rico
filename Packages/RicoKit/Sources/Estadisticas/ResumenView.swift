import SwiftUI
import SwiftData
import Charts
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Pestaña Resumen: gasto, visitas y lo mejor del mes, y «Tu año en Rico» con Premium.
public struct ResumenView: View {
    @Query(
        filter: #Predicate<Visita> { $0.estadoRaw == "valorada" },
        sort: \Visita.fecha,
        order: .reverse
    )
    private var visitas: [Visita]

    @State private var mes: Date
    @Environment(\.dynamicTypeSize) private var tamanoTexto

    private let calendario: Calendar

    public init() {
        let calendario = CalculadoraResumen.calendarioEspanol()
        self.calendario = calendario
        _mes = State(initialValue: CalculadoraResumen.inicioMes(.now, calendario: calendario))
    }

    public var body: some View {
        let resumibles = visitas.map { VisitaResumible($0) }
        let resumen = CalculadoraResumen.resumen(de: resumibles, mes: mes, calendario: calendario)
        let restaurantes = Dictionary(
            visitas.compactMap { visita in visita.restaurante.map { ($0.id, $0) } },
            uniquingKeysWith: { primero, _ in primero }
        )

        return NavigationStack {
            ScrollView {
                if !visitas.isEmpty {
                    VStack(alignment: .leading, spacing: 22) {
                        selectorMes
                        if resumen.estaVacio {
                            vacioMes(resumibles)
                        } else {
                            cifras(resumen)
                            graficoSemanas(resumen)
                            topDelMes(resumen, restaurantes: restaurantes)
                        }
                        TuAnoView(
                            resumen: CalculadoraResumen.resumenAnual(de: resumibles, hasta: mes, calendario: calendario),
                            formato: formato
                        )
                    }
                    .padding(.horizontal, Medidas.margen)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.ricoFondo)
            .overlay {
                if visitas.isEmpty { vacioTotal }
            }
            .cabeceraRaiz(CabeceraRaiz(Text("Resumen", bundle: .module)) {})
            .navigationDestination(for: Restaurante.self) { restaurante in
                FichaRestauranteView(restaurante: restaurante)
            }
        }
    }

    private var formato: FormatoResumen { FormatoResumen(calendario: calendario) }

    // MARK: Selector de mes

    private var selectorMes: some View {
        let puedeAvanzar = CalculadoraResumen.puedeAvanzar(desde: mes, ahora: .now, calendario: calendario)
        return HStack(spacing: 8) {
            botonMes(simbolo: "chevron.left", etiqueta: Text("Mes anterior", bundle: .module), activo: true) {
                mes = CalculadoraResumen.mes(mes, desplazado: -1, calendario: calendario)
            }
            Spacer(minLength: 0)
            Text(formato.mesYAno(mes))
                .font(.rico(.title2, peso: .black))
                .foregroundStyle(Color.ricoTinta)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            botonMes(simbolo: "chevron.right", etiqueta: Text("Mes siguiente", bundle: .module), activo: puedeAvanzar) {
                mes = CalculadoraResumen.mes(mes, desplazado: 1, calendario: calendario)
            }
        }
        .padding(.top, 4)
        .animation(.snappy(duration: 0.25), value: mes)
        .sensoryFeedback(.selection, trigger: mes)
    }

    private func botonMes(simbolo: String, etiqueta: Text, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.rico(.headline, peso: .bold))
                .foregroundStyle(Color.ricoTinta)
                .frame(width: Medidas.toqueMinimo, height: Medidas.toqueMinimo)
                .background(Color.ricoSuperficie, in: Circle())
                .overlay(Circle().strokeBorder(Color.ricoLinea))
                .opacity(activo ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!activo)
        .accessibilityLabel(etiqueta)
    }

    // MARK: Cifras

    @ViewBuilder
    private func cifras(_ resumen: ResumenMes) -> some View {
        let cifras = resumen.cifras
        let mesAnterior = formato.mes(CalculadoraResumen.mes(resumen.mes, desplazado: -1, calendario: calendario))
        let visitas = TarjetaCifra(
            titulo: Text("Visitas", bundle: .module),
            valor: Text(cifras.visitas, format: .number),
            detalle: resumen.comparacion.visitas.map { textoDiferencia($0, mesAnterior: mesAnterior) }
        )
        let porPersona = TarjetaCifra(
            titulo: Text("Por persona", bundle: .module),
            valor: cifras.gastoMedioPorPersona.map { Text($0.textoMoneda) } ?? Text(verbatim: "—"),
            detalle: Text("De media", bundle: .module)
        )
        let nota = TarjetaCifra(
            titulo: Text("Nota media", bundle: .module),
            valor: cifras.notaMedia.map { Text("★ \(NotaTexto.texto($0))", bundle: .module) } ?? Text(verbatim: "—"),
            detalle: nil,
            etiquetaAccesible: cifras.notaMedia.map { Text("\(NotaTexto.texto($0)) de 5 estrellas", bundle: .module) }
        )
        let sitios = TarjetaCifra(
            titulo: Text("Sitios", bundle: .module),
            valor: Text("^[\(cifras.sitiosNuevos) nuevo](inflect: true)", bundle: .module),
            detalle: Text("^[\(cifras.sitiosRepetidos) repetido](inflect: true)", bundle: .module)
        )

        VStack(spacing: 12) {
            TarjetaCifra(
                titulo: Text("Gasto del mes", bundle: .module),
                valor: cifras.gasto.map { Text($0.textoMoneda) } ?? Text("Sin importes", bundle: .module),
                detalle: resumen.comparacion.gasto.map { textoVariacion($0, mesAnterior: mesAnterior) },
                grande: true
            )
            if tamanoTexto.isAccessibilitySize {
                VStack(spacing: 12) {
                    visitas
                    porPersona
                    nota
                    sitios
                }
            } else {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        visitas.gridCellAnchor(.topLeading)
                        porPersona.gridCellAnchor(.topLeading)
                    }
                    GridRow {
                        nota.gridCellAnchor(.topLeading)
                        sitios.gridCellAnchor(.topLeading)
                    }
                }
            }
        }
    }

    private func textoVariacion(_ variacion: Double, mesAnterior: String) -> Text {
        if abs(variacion) < 0.005 {
            return Text("Igual que \(mesAnterior)", bundle: .module)
        }
        let porcentaje = variacion.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
        return Text("\(porcentaje) que \(mesAnterior)", bundle: .module)
    }

    private func textoDiferencia(_ diferencia: Int, mesAnterior: String) -> Text {
        if diferencia > 0 {
            return Text("^[\(diferencia) visita](inflect: true) más que \(mesAnterior)", bundle: .module)
        } else if diferencia < 0 {
            return Text("^[\(-diferencia) visita](inflect: true) menos que \(mesAnterior)", bundle: .module)
        }
        return Text("Igual que \(mesAnterior)", bundle: .module)
    }

    // MARK: Gráfico de semanas

    private func graficoSemanas(_ resumen: ResumenMes) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TituloSeccion(Text("Gasto por semanas", bundle: .module))
            Tarjeta {
                if resumen.cifras.gasto == nil {
                    Text("Este mes no has apuntado lo que gastaste. Añade el importe al valorar y aquí verás tus semanas.", bundle: .module)
                        .font(.rico(.subheadline, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                } else {
                    Chart(resumen.semanas) { semana in
                        BarMark(
                            x: .value(String(localized: "Semana", bundle: .module), etiquetaSemana(semana)),
                            y: .value(String(localized: "Gasto", bundle: .module), semana.gasto.euros)
                        )
                        .foregroundStyle(Color.ricoTomate)
                        .cornerRadius(6)
                        .accessibilityLabel(Text("Del \(semana.diaInicio) al \(semana.diaFin) de \(formato.mes(resumen.mes))", bundle: .module))
                        .accessibilityValue(Text("\(semana.gasto.textoMoneda), ^[\(semana.visitas) visita](inflect: true)", bundle: .module))
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.rico(.caption, peso: .semibold))
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
                    .frame(height: 190)
                }
            }
        }
    }

    /// «1–4», «5–11»: los días de la semana dentro del mes.
    private func etiquetaSemana(_ semana: GastoSemana) -> String {
        semana.diaInicio == semana.diaFin ? "\(semana.diaInicio)" : "\(semana.diaInicio)–\(semana.diaFin)"
    }

    // MARK: Top del mes

    @ViewBuilder
    private func topDelMes(_ resumen: ResumenMes, restaurantes: [UUID: Restaurante]) -> some View {
        if !resumen.mejoresSitios.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TituloSeccion(Text("Tu top del mes", bundle: .module))
                VStack(spacing: 0) {
                    ForEach(Array(resumen.mejoresSitios.enumerated()), id: \.element.id) { posicion, sitio in
                        let restaurante = sitio.restauranteID.flatMap { restaurantes[$0] }
                        if let restaurante {
                            NavigationLink(value: restaurante) {
                                filaSitio(sitio, posicion: posicion + 1, navegable: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            filaSitio(sitio, posicion: posicion + 1, navegable: false)
                        }
                        if posicion < resumen.mejoresSitios.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .superficieTarjeta()
            }
        }

        if !resumen.platosEncanto.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TituloSeccion(Text("Platos que te encantaron", bundle: .module))
                Tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(resumen.platosEncanto.prefix(6)) { plato in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "heart.fill")
                                    .font(.rico(.subheadline, peso: .bold))
                                    .foregroundStyle(Color.ricoVerde)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plato.nombre)
                                        .font(.rico(.body, peso: .bold))
                                        .foregroundStyle(Color.ricoTinta)
                                    Text(plato.restaurante)
                                        .font(.rico(.footnote, peso: .semibold))
                                        .foregroundStyle(Color.ricoSecundario)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func filaSitio(_ sitio: SitioDestacado, posicion: Int, navegable: Bool) -> some View {
        HStack(spacing: 14) {
            Text(posicion, format: .number)
                .font(.rico(.title3, peso: .black))
                .foregroundStyle(Color.ricoSecundario)
                .frame(minWidth: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(sitio.nombre)
                    .font(.rico(.headline, peso: .heavy))
                    .foregroundStyle(Color.ricoTinta)
                Text(detalleSitio(sitio))
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            Spacer(minLength: 8)
            NotaCompacta(nota: sitio.notaMedia)
                .foregroundStyle(Color.ricoTinta)
            if navegable {
                Image(systemName: "chevron.right")
                    .font(.rico(.footnote, peso: .bold))
                    .foregroundStyle(Color.ricoSecundario)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Medidas.toqueMinimo)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Número \(posicion): \(sitio.nombre)", bundle: .module))
    }

    private func detalleSitio(_ sitio: SitioDestacado) -> String {
        let visitas = String(AttributedString(localized: "^[\(sitio.visitas) visita](inflect: true)", bundle: .module).characters)
        return [sitio.ciudad, visitas].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Estados vacíos

    private func vacioMes(_ resumibles: [VisitaResumible]) -> some View {
        let esMesActual = !CalculadoraResumen.puedeAvanzar(desde: mes, ahora: .now, calendario: calendario)
        let anterior = CalculadoraResumen.ultimoMesConVisitas(resumibles, antesDe: mes, calendario: calendario)
        return Tarjeta {
            VStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.rico(.title, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
                    .accessibilityHidden(true)
                Text("Sin visitas en \(formato.mes(mes))", bundle: .module)
                    .font(.rico(.headline, peso: .heavy))
                    .foregroundStyle(Color.ricoTinta)
                Group {
                    if esMesActual {
                        Text("Cuando valores un sitio en el Diario, aquí verás lo que has gastado y lo que más te gustó.", bundle: .module)
                    } else {
                        Text("Ese mes no guardaste ningún sitio.", bundle: .module)
                    }
                }
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
                if let anterior {
                    Button {
                        mes = anterior
                    } label: {
                        Text("Ver \(formato.mes(anterior))", bundle: .module)
                    }
                    .buttonStyle(.ricoSecundario)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var vacioTotal: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                SimboloRico()
                    .frame(width: 72, height: 72)
                Text("Tu resumen está vacío", bundle: .module)
            }
        } description: {
            Text("Valora tu primera visita en el Diario y aquí verás lo que gastas y tus sitios favoritos.", bundle: .module)
        }
    }
}

/// Tarjeta con una cifra del mes.
struct TarjetaCifra: View {
    let titulo: Text
    let valor: Text
    let detalle: Text?
    var grande = false
    var etiquetaAccesible: Text?

    var body: some View {
        Tarjeta(llena: true) {
            VStack(alignment: .leading, spacing: 4) {
                titulo
                    .font(.rico(.footnote, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
                valor
                    .font(.rico(grande ? .largeTitle : .title2, peso: .black))
                    .foregroundStyle(Color.ricoTinta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(etiquetaAccesible ?? valor)
                if let detalle {
                    detalle
                        .font(.rico(.footnote, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
