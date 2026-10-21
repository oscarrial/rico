import SwiftUI
import MapKit
import DesignSystem
import RicoCore

/// Punto elegido en el mapa para un sitio escrito a mano.
struct UbicacionElegida: Sendable {
    var latitud: Double
    var longitud: Double
    var direccion: String?
    var ciudad: String?
}

/// Elige dónde está un sitio: se mueve el mapa hasta poner el pin encima o se busca
/// por nombre. La dirección se rellena sola con geocodificación inversa.
struct SelectorUbicacionView: View {
    @Environment(\.dismiss) private var cerrar

    let alElegir: (UbicacionElegida) -> Void

    @State private var posicion: MapCameraPosition
    @State private var centro: CLLocationCoordinate2D
    @State private var texto = ""
    @State private var resultados: [LugarEncontrado] = []
    @State private var buscando = false
    @State private var direccion: String?
    @State private var ciudad: String?
    @State private var resolviendo = false
    @State private var tareaDireccion: Task<Void, Never>?

    private let buscador: any BuscadorLugares = BuscadorMapKit()

    init(inicial: CLLocationCoordinate2D? = nil, alElegir: @escaping (UbicacionElegida) -> Void) {
        let centro = inicial ?? CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        self.alElegir = alElegir
        _centro = State(initialValue: centro)
        _posicion = State(initialValue: .region(
            MKCoordinateRegion(center: centro, latitudinalMeters: 1200, longitudinalMeters: 1200)
        ))
    }

    var body: some View {
        NavigationStack {
            Map(position: $posicion) {
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket])))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .onEnd) { camara in
                centro = camara.region.center
                resolverDireccion(camara.region.center)
            }
            .overlay { pin }
            .safeAreaInset(edge: .top, spacing: 0) { buscadorSuperior }
            .safeAreaInset(edge: .bottom, spacing: 0) { barraInferior }
            .navigationTitle(Text("Ubicación", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
                }
            }
            .task(id: texto) { await buscar() }
            .onDisappear { tareaDireccion?.cancel() }
            .onAppear { resolverDireccion(centro) }
        }
        .tint(.ricoTomate)
    }

    // MARK: Pin

    private var pin: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.ricoTomate)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Circle()
                .fill(.black.opacity(0.18))
                .frame(width: 12, height: 4)
                .blur(radius: 1)
        }
        .offset(y: -16)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Buscador

    private var buscadorSuperior: some View {
        VStack(alignment: .leading, spacing: 10) {
            CampoBusqueda(texto: $texto, ejemplo: Text("Busca el sitio o la calle", bundle: .module))
                .overlay(alignment: .trailing) {
                    if buscando {
                        ProgressView()
                            .padding(.trailing, 12)
                    }
                }
            if !resultados.isEmpty {
                VStack(spacing: 0) {
                    ForEach(resultados.prefix(5)) { lugar in
                        Button {
                            elegirResultado(lugar)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lugar.nombre)
                                    .font(.rico(.subheadline, peso: .heavy))
                                    .foregroundStyle(Color.ricoTinta)
                                if let detalle = [lugar.direccion, lugar.ciudad].compactMap({ $0 }).joined(separator: ", ").nilSiVacio {
                                    Text(detalle)
                                        .font(.rico(.footnote, peso: .semibold))
                                        .foregroundStyle(Color.ricoSecundario)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if lugar.id != resultados.prefix(5).last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
            }
        }
        .padding(.horizontal, Medidas.margen)
        .padding(.vertical, 8)
    }

    // MARK: Barra inferior

    private var barraInferior: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("El pin marca el sitio", bundle: .module)
                    .font(.rico(.footnote, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
                if let direccion, !direccion.isEmpty {
                    Text(direccion)
                        .font(.rico(.subheadline, peso: .bold))
                        .foregroundStyle(Color.ricoTinta)
                        .lineLimit(2)
                } else {
                    Text(resolviendo ? "Buscando la dirección…" : "Mueve el mapa para colocarlo", bundle: .module)
                        .font(.rico(.subheadline, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                }
            }
            Button {
                alElegir(UbicacionElegida(
                    latitud: centro.latitude,
                    longitud: centro.longitude,
                    direccion: direccion,
                    ciudad: ciudad
                ))
                cerrar()
            } label: {
                Text("Usar esta ubicación", bundle: .module)
            }
            .buttonStyle(.ricoPrincipal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Medidas.margen)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .fondoBarraInferior()
    }

    // MARK: Acciones

    private func elegirResultado(_ lugar: LugarEncontrado) {
        let coordenada = CLLocationCoordinate2D(latitude: lugar.latitud, longitude: lugar.longitud)
        centro = coordenada
        posicion = .region(MKCoordinateRegion(center: coordenada, latitudinalMeters: 500, longitudinalMeters: 500))
        direccion = lugar.direccion
        ciudad = lugar.ciudad
        texto = ""
        resultados = []
    }

    private func buscar() async {
        let consulta = texto.recortado
        guard consulta.count >= 2 else {
            resultados = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        buscando = true
        defer { buscando = false }
        resultados = (try? await buscador.buscar(consulta)) ?? []
    }

    private func resolverDireccion(_ coordenada: CLLocationCoordinate2D) {
        tareaDireccion?.cancel()
        tareaDireccion = Task {
            resolviendo = true
            defer { resolviendo = false }
            let punto = CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude)
            let marca = try? await CLGeocoder().reverseGeocodeLocation(punto).first
            guard !Task.isCancelled else { return }
            let calle = [marca?.thoroughfare, marca?.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            direccion = calle.isEmpty ? marca?.name : calle
            ciudad = marca?.locality
        }
    }
}
