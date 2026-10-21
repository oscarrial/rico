import SwiftUI
import DesignSystem
import Modelos
import RicoCore

/// Registro manual: buscar el restaurante en Apple Maps (o escribirlo a mano) y valorar.
public struct AltaManualView: View {
    @Environment(\.dismiss) private var cerrar

    @State private var texto = ""
    @State private var resultados: [LugarEncontrado] = []
    @State private var buscando = false
    @State private var fallo = false
    @State private var ruta = NavigationPath()

    /// Pasos del alta a mano: primero el formulario, después la ficha.
    enum PasoManual: Hashable {
        case formulario(String)
        case ficha(RestauranteManual)
    }

    private let buscador: any BuscadorLugares

    public init(buscador: any BuscadorLugares = BuscadorMapKit()) {
        self.buscador = buscador
    }

    public var body: some View {
        NavigationStack(path: $ruta) {
            List {
                ForEach(resultados) { lugar in
                    NavigationLink(value: lugar) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lugar.nombre)
                                .font(.rico(.body, peso: .heavy))
                            if let detalle = [lugar.direccion, lugar.ciudad].compactMap({ $0 }).joined(separator: ", ").nilSiVacio {
                                Text(detalle)
                                    .font(.rico(.footnote, peso: .semibold))
                                    .foregroundStyle(Color.ricoSecundario)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if !texto.recortado.isEmpty {
                    NavigationLink(value: PasoManual.formulario(texto.recortado)) {
                        Label {
                            Text("Añadir «\(texto.recortado)» a mano", bundle: .module)
                                .font(.rico(.body, peso: .heavy))
                        } icon: {
                            Image(systemName: "square.and.pencil")
                        }
                        .foregroundStyle(Color.ricoTomateTexto)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.ricoFondo)
            .overlay { estado }
            .navigationTitle(Text("Nueva visita", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $texto,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("¿Dónde has comido?", bundle: .module)
            )
            .task(id: texto) { await buscar() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: PasoManual.formulario(texto.recortado)) {
                        Text("A mano", bundle: .module)
                    }
                }
            }
            .navigationDestination(for: LugarEncontrado.self) { lugar in
                FichaRapidaView(modelo: FichaRapidaModelo(lugar: lugar)) { _ in
                    cerrar()
                }
            }
            .navigationDestination(for: PasoManual.self) { paso in
                switch paso {
                case let .formulario(nombre):
                    FormularioRestauranteView(nombreInicial: nombre) { datos in
                        ruta.append(PasoManual.ficha(datos))
                    }
                case let .ficha(datos):
                    FichaRapidaView(modelo: FichaRapidaModelo(manual: datos)) { _ in
                        cerrar()
                    }
                }
            }
        }
        .tint(.ricoTomate)
    }

    @ViewBuilder
    private var estado: some View {
        if fallo {
            ContentUnavailableView {
                Label { Text("No se pudo buscar", bundle: .module) } icon: { Image(systemName: "wifi.exclamationmark") }
            } description: {
                Text("Comprueba la conexión y vuelve a intentarlo.", bundle: .module)
            }
        } else if resultados.isEmpty, !buscando, texto.recortado.count >= 2 {
            ContentUnavailableView {
                Label { Text("No aparece en el mapa", bundle: .module) } icon: { Image(systemName: "mappin.slash") }
            } description: {
                Text("Puedes añadirlo escribiendo su nombre.", bundle: .module)
            } actions: {
                NavigationLink(value: PasoManual.formulario(texto.recortado)) {
                    Text("Añadir «\(texto.recortado)» a mano", bundle: .module)
                }
                .buttonStyle(.ricoPrincipal)
                .padding(.horizontal, 40)
            }
        } else if texto.recortado.isEmpty {
            ContentUnavailableView {
                Label { Text("Busca el restaurante", bundle: .module) } icon: { Image(systemName: "magnifyingglass") }
            } description: {
                Text("Escribe el nombre del sitio. Si no aparece, pulsa «A mano». Podrás cambiar la fecha si fue otro día.", bundle: .module)
            }
        }
    }

    private func buscar() async {
        // Espera a que el usuario deje de escribir.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        buscando = true
        defer { buscando = false }
        do {
            let encontrados = try await buscador.buscar(texto)
            guard !Task.isCancelled else { return }
            resultados = encontrados
            fallo = false
        } catch {
            guard !Task.isCancelled else { return }
            if !(error is CancellationError) {
                Registro.busqueda.error("Falló la búsqueda de lugares: \(String(describing: error), privacy: .private)")
            }
            resultados = []
            fallo = (error as? CancellationError) == nil && texto.recortado.count >= 2
        }
    }
}
