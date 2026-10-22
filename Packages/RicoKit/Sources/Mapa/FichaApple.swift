import MapKit
import SwiftUI
import DesignSystem

/// «Reseñas y fotos»: abre la ficha del sitio en Apple Maps (valoraciones, fotos, horario y
/// descripción) sin salir de Rico. Desde iOS 18 sale como hoja; antes, en la app Mapas.
struct BotonFichaApple: View {
    /// Identificador de Apple Maps (`MKMapItem.Identifier`). Sin él, se busca por nombre.
    let mapItemID: String?
    let nombre: String
    let latitud: Double
    let longitud: Double

    @Environment(\.openURL) private var abrirURL
    @State private var item: MKMapItem?
    @State private var cargando = false

    var body: some View {
        Button {
            Task { await abrir() }
        } label: {
            Label {
                Text("Reseñas, fotos y horario", bundle: .module)
            } icon: {
                if cargando {
                    ProgressView()
                } else {
                    Image(systemName: "star.bubble")
                }
            }
            .font(.rico(.subheadline, peso: .heavy))
            .foregroundStyle(Color.ricoTomateTexto)
            .frame(minHeight: Medidas.toqueMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cargando)
        .modifier(HojaFichaApple(item: $item))
    }

    private func abrir() async {
        if #available(iOS 18.0, *), let mapItemID {
            cargando = true
            defer { cargando = false }
            if let encontrado = await Self.buscar(mapItemID).item {
                item = encontrado
                return
            }
        }
        if let url = Self.urlMapas(nombre: nombre, latitud: latitud, longitud: longitud) {
            abrirURL(url)
        }
    }

    /// MapKit no marca `MKMapItem` como `Sendable`: se pide fuera del actor principal y se
    /// entrega en una caja. El objeto no se toca desde dos sitios a la vez.
    @available(iOS 18.0, *)
    private nonisolated static func buscar(_ id: String) async -> CajaMapItem {
        guard let identificador = MKMapItem.Identifier(rawValue: id) else { return CajaMapItem(item: nil) }
        return CajaMapItem(item: try? await MKMapItemRequest(mapItemIdentifier: identificador).mapItem)
    }

    /// El sitio en la app Mapas, buscando el nombre junto a sus coordenadas.
    static func urlMapas(nombre: String, latitud: Double, longitud: Double) -> URL? {
        var partes = URLComponents(string: "https://maps.apple.com/")
        partes?.queryItems = [
            URLQueryItem(name: "q", value: nombre),
            URLQueryItem(name: "ll", value: "\(latitud),\(longitud)")
        ]
        return partes?.url
    }
}

private struct CajaMapItem: @unchecked Sendable {
    let item: MKMapItem?
}

private struct HojaFichaApple: ViewModifier {
    @Binding var item: MKMapItem?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.mapItemDetailSheet(item: $item)
        } else {
            content
        }
    }
}
