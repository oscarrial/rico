import SwiftUI
import CoreLocation
import DesignSystem
import RicoCore

/// Alta de un restaurante escrito a mano, cuando no aparece en Apple Maps.
struct FormularioRestauranteView: View {
    @State private var nombre: String
    @State private var ciudad = ""
    @State private var direccion = ""
    @State private var ubicacion: UbicacionElegida?
    @State private var eligiendoUbicacion = false
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

                botonUbicacion

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
        .sheet(isPresented: $eligiendoUbicacion) {
            SelectorUbicacionView(inicial: ubicacion.map { CLLocationCoordinate2D(latitude: $0.latitud, longitude: $0.longitud) }) { elegida in
                ubicacion = elegida
                if ciudad.recortado.isEmpty, let nuevaCiudad = elegida.ciudad { ciudad = nuevaCiudad }
                if direccion.recortado.isEmpty, let nuevaDireccion = elegida.direccion { direccion = nuevaDireccion }
            }
        }
    }

    private var botonUbicacion: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ubicación (opcional)", bundle: .module)
                .font(.rico(.footnote, peso: .heavy))
                .foregroundStyle(Color.ricoSecundario)
            Button {
                campo = nil
                eligiendoUbicacion = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: ubicacion == nil ? "mappin.and.ellipse" : "mappin.circle.fill")
                        .font(.rico(.title3, peso: .bold))
                        .foregroundStyle(ubicacion == nil ? Color.ricoSecundario : Color.ricoTomate)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if let ubicacion {
                            Text("Marcada en el mapa", bundle: .module)
                                .font(.rico(.body, peso: .heavy))
                                .foregroundStyle(Color.ricoTinta)
                            Text(ubicacion.direccion ?? ubicacion.ciudad ?? String(localized: "Toca para cambiarla", bundle: .module))
                                .font(.rico(.footnote, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                                .lineLimit(1)
                        } else {
                            Text("Elegir en el mapa", bundle: .module)
                                .font(.rico(.body, peso: .heavy))
                                .foregroundStyle(Color.ricoTinta)
                            Text("Así el sitio aparecerá en tu mapa", bundle: .module)
                                .font(.rico(.footnote, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.rico(.footnote, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: Medidas.alturaBoton, alignment: .leading)
                .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                ubicacion == nil
                    ? Text("Elegir la ubicación en el mapa", bundle: .module)
                    : Text("Cambiar la ubicación en el mapa", bundle: .module)
            )
            if ubicacion != nil {
                Button {
                    ubicacion = nil
                } label: {
                    Text("Quitar la ubicación", bundle: .module)
                        .font(.rico(.footnote, peso: .heavy))
                        .foregroundStyle(Color.ricoTomateTexto)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
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
            direccion: direccion.nilSiVacio,
            latitud: ubicacion?.latitud,
            longitud: ubicacion?.longitud
        ))
    }
}
