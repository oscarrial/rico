import SwiftUI
import DesignSystem
import RicoCore

/// Alta de un restaurante escrito a mano, cuando no aparece en Apple Maps.
struct FormularioRestauranteView: View {
    @State private var nombre: String
    @State private var ciudad = ""
    @State private var direccion = ""
    @FocusState private var campo: Campo?

    private let alContinuar: (RestauranteManual) -> Void

    enum Campo { case nombre, ciudad, direccion }

    init(nombreInicial: String, alContinuar: @escaping (RestauranteManual) -> Void) {
        _nombre = State(initialValue: nombreInicial)
        self.alContinuar = alContinuar
    }

    private var puedeContinuar: Bool { !nombre.recortado.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Si no aparece en el buscador, escríbelo tú. Podrás valorarlo igual.", bundle: .module)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)

                campoTexto(
                    titulo: Text("Nombre", bundle: .module),
                    ejemplo: Text("Taberna O Grelo", bundle: .module),
                    texto: $nombre,
                    foco: .nombre,
                    siguiente: .ciudad
                )
                campoTexto(
                    titulo: Text("Ciudad (opcional)", bundle: .module),
                    ejemplo: Text("Vigo", bundle: .module),
                    texto: $ciudad,
                    foco: .ciudad,
                    siguiente: .direccion
                )
                campoTexto(
                    titulo: Text("Dirección (opcional)", bundle: .module),
                    ejemplo: Text("Rúa Real, 12", bundle: .module),
                    texto: $direccion,
                    foco: .direccion,
                    siguiente: nil
                )

                Button(action: continuar) {
                    Text("Continuar", bundle: .module)
                }
                .buttonStyle(.ricoPrincipal)
                .disabled(!puedeContinuar)
                .padding(.top, 8)
            }
            .padding(.horizontal, Medidas.margen)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ricoFondo)
        .navigationTitle(Text("Añadir a mano", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { campo = nombre.isEmpty ? .nombre : .ciudad }
    }

    private func campoTexto(titulo: Text, ejemplo: Text, texto: Binding<String>, foco: Campo, siguiente: Campo?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            titulo
                .font(.rico(.footnote, peso: .heavy))
                .foregroundStyle(Color.ricoSecundario)
            TextField(text: texto, prompt: ejemplo) { titulo }
                .font(.rico(.body, peso: .bold))
                .textInputAutocapitalization(.words)
                .submitLabel(siguiente == nil ? .done : .next)
                .focused($campo, equals: foco)
                .onSubmit {
                    if let siguiente { campo = siguiente } else { continuar() }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: Medidas.alturaBoton)
                .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
        }
    }

    private func continuar() {
        guard puedeContinuar else { return }
        alContinuar(RestauranteManual(
            nombre: nombre.recortado,
            ciudad: ciudad.nilSiVacio,
            direccion: direccion.nilSiVacio
        ))
    }
}
