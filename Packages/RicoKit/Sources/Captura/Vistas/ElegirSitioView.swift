import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// «Elegir sitio»: el usuario dice dónde fue un pago. Busca en su diario y en Apple Maps
/// (alrededor del pago si se sabe dónde fue).
public struct ElegirSitioView: View {
    @Environment(\.modelContext) private var contexto

    let visita: Visita
    let alElegir: (Visita) -> Void

    @Query(sort: \Restaurante.nombre) private var restaurantes: [Restaurante]
    @State private var texto: String
    @State private var resultados: [LugarEncontrado] = []
    @State private var buscando = false
    @State private var fallo = false
    @State private var errorGuardar = false

    private let buscador: any BuscadorLugares
    private let buscadorCercano: any BuscadorLugaresCercanos

    /// - Parameter alElegir: se llama con la visita ya asignada a su restaurante.
    public init(
        visita: Visita,
        buscador: any BuscadorLugares = BuscadorMapKit(),
        buscadorCercano: any BuscadorLugaresCercanos = BuscadorCercanoMapKit(),
        alElegir: @escaping (Visita) -> Void
    ) {
        self.visita = visita
        self.buscador = buscador
        self.buscadorCercano = buscadorCercano
        self.alElegir = alElegir
        _texto = State(initialValue: Self.textoInicial(visita))
    }

    public var body: some View {
        List {
            Section {
                cabecera
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !delDiario.isEmpty {
                Section {
                    ForEach(delDiario) { restaurante in
                        Button {
                            elegir { try AccionesBandeja.asignar(visita, restaurante: restaurante, en: contexto) }
                        } label: {
                            fila(nombre: restaurante.nombre, detalle: [restaurante.direccion, restaurante.ciudad])
                        }
                    }
                } header: {
                    Text("En tu diario", bundle: .module)
                }
            }

            if !resultados.isEmpty {
                Section {
                    ForEach(resultados) { lugar in
                        Button {
                            elegir { try AccionesBandeja.asignar(visita, lugar: lugar, en: contexto) }
                        } label: {
                            fila(nombre: lugar.nombre, detalle: [lugar.direccion, lugar.ciudad])
                        }
                    }
                } header: {
                    Text("En el mapa", bundle: .module)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ricoFondo)
        .overlay { estado }
        .navigationTitle(Text("¿Dónde fue?", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $texto,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Nombre del sitio", bundle: .module)
        )
        .task(id: texto) { await buscar() }
        .alert(Text("No se pudo guardar el sitio", bundle: .module), isPresented: $errorGuardar) {
            Button { } label: { Text("Vale", bundle: .module) }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pago = visita.pago {
                Text(pago.comercioBruto)
                    .font(.rico(.headline, peso: .heavy))
                    .foregroundStyle(Color.ricoTinta)
                Text(verbatim: "\(FormatoFecha.corta(pago.fecha)) · \(pago.importe.textoMoneda)")
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            Text("Busca el restaurante donde pagaste. La próxima vez Rico lo reconocerá solo.", bundle: .module)
                .font(.rico(.footnote, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }

    private func fila(nombre: String, detalle: [String?]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nombre)
                .font(.rico(.body, peso: .heavy))
                .foregroundStyle(Color.ricoTinta)
            let lineaDetalle = detalle.compactMap { $0 }.joined(separator: ", ")
            if !lineaDetalle.isEmpty {
                Text(lineaDetalle)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Medidas.toqueMinimo, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var estado: some View {
        if fallo, resultados.isEmpty, delDiario.isEmpty {
            ContentUnavailableView {
                Label { Text("No se pudo buscar", bundle: .module) } icon: { Image(systemName: "wifi.exclamationmark") }
            } description: {
                Text("Comprueba la conexión y vuelve a intentarlo.", bundle: .module)
            }
        } else if !buscando, resultados.isEmpty, delDiario.isEmpty, texto.nilSiVacio != nil {
            ContentUnavailableView {
                Label { Text("No aparece", bundle: .module) } icon: { Image(systemName: "mappin.slash") }
            } description: {
                Text("Prueba con otro nombre o solo una parte.", bundle: .module)
            }
        }
    }

    /// Restaurantes del diario cuyo nombre contiene lo escrito.
    private var delDiario: [Restaurante] {
        guard let consulta = texto.nilSiVacio else { return [] }
        return Array(restaurantes.filter { r in
            r.nombre.range(of: consulta, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || Emparejador.similitudTexto(LimpiadorComercio.limpiar(consulta), LimpiadorComercio.limpiar(r.nombre)) >= 0.85
        }.prefix(5))
    }

    private func elegir(_ asignar: () throws -> Void) {
        do {
            try asignar()
            NotificadorLocal().cancelar(visitaID: visita.id)
            alElegir(visita)
        } catch {
            contexto.rollback()
            Registro.captura.error("No se pudo asignar el sitio: \(String(describing: error), privacy: .public)")
            errorGuardar = true
        }
    }

    private func buscar() async {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        guard let consulta = texto.nilSiVacio, consulta.count >= 2 else {
            resultados = []
            return
        }
        buscando = true
        defer { buscando = false }
        do {
            let encontrados: [LugarEncontrado]
            if let pago = visita.pago, let lat = pago.latitud, let lon = pago.longitud {
                encontrados = try await buscadorCercano.buscar(consulta, cerca: Coordenada(latitud: lat, longitud: lon), radioMetros: 3000)
            } else {
                encontrados = try await buscador.buscar(consulta)
            }
            guard !Task.isCancelled else { return }
            resultados = encontrados
            fallo = false
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            Registro.busqueda.error("Falló la búsqueda de lugares: \(String(describing: error), privacy: .private)")
            resultados = []
            fallo = true
        }
    }

    private static func textoInicial(_ visita: Visita) -> String {
        guard let limpio = visita.pago?.comercioLimpio, !limpio.isEmpty else { return "" }
        return limpio.capitalized
    }
}
