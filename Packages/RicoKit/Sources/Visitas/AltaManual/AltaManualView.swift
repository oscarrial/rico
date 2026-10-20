import SwiftUI
import DesignSystem
import RicoCore

/// Registro manual: buscar el restaurante en Apple Maps y valorar.
public struct AltaManualView: View {
    @Environment(\.dismiss) private var cerrar

    @State private var texto = ""
    @State private var resultados: [LugarEncontrado] = []
    @State private var buscando = false
    @State private var fallo = false
    @State private var ruta: [LugarEncontrado] = []

    private let buscador: any BuscadorLugares

    public init(buscador: any BuscadorLugares = BuscadorMapKit()) {
        self.buscador = buscador
    }

    public var body: some View {
        NavigationStack(path: $ruta) {
            List(resultados) { lugar in
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
            .listStyle(.plain)
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
            }
            .navigationDestination(for: LugarEncontrado.self) { lugar in
                FichaRapidaView(modelo: FichaRapidaModelo(lugar: lugar)) { _ in
                    cerrar()
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
            ContentUnavailableView.search(text: texto)
        } else if texto.recortado.isEmpty {
            ContentUnavailableView {
                Label { Text("Busca el restaurante", bundle: .module) } icon: { Image(systemName: "magnifyingglass") }
            } description: {
                Text("Escribe el nombre del sitio. Podrás cambiar la fecha si fue otro día.", bundle: .module)
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
            resultados = []
            fallo = (error as? CancellationError) == nil && texto.recortado.count >= 2
        }
    }
}
