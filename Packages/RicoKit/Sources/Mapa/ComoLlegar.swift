import SwiftUI
import DesignSystem

/// «Cómo llegar»: abre la ruta hasta el sitio en Mapas de Apple o en Google Maps, a elegir.
struct BotonComoLlegar: View {
    let nombre: String
    let latitud: Double
    let longitud: Double

    @Environment(\.openURL) private var abrirURL
    @State private var eligiendo = false

    var body: some View {
        Button {
            eligiendo = true
        } label: {
            Label {
                Text("Cómo llegar", bundle: .module)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond")
            }
        }
        .buttonStyle(.ricoSecundario)
        .confirmationDialog(
            Text("Cómo llegar a \(nombre)", bundle: .module),
            isPresented: $eligiendo,
            titleVisibility: .visible
        ) {
            Button {
                if let url = RutaMapas.apple(latitud: latitud, longitud: longitud) { abrirURL(url) }
            } label: {
                Text("Mapas de Apple", bundle: .module)
            }
            Button {
                abrirGoogleMaps()
            } label: {
                Text("Google Maps", bundle: .module)
            }
        }
    }

    /// La app de Google Maps si está instalada; si no, la web (que ofrece instalarla).
    private func abrirGoogleMaps() {
        guard let app = RutaMapas.googleApp(latitud: latitud, longitud: longitud) else { return }
        abrirURL(app) { abierta in
            if !abierta, let web = RutaMapas.googleWeb(latitud: latitud, longitud: longitud) {
                abrirURL(web)
            }
        }
    }
}

/// Enlaces de ruta hasta unas coordenadas. Con coordenadas y no con el nombre, para que
/// ninguna app confunda el sitio con otro que se llame igual.
enum RutaMapas {
    static func apple(latitud: Double, longitud: Double) -> URL? {
        var partes = URLComponents(string: "https://maps.apple.com/")
        partes?.queryItems = [URLQueryItem(name: "daddr", value: destino(latitud, longitud))]
        return partes?.url
    }

    static func googleApp(latitud: Double, longitud: Double) -> URL? {
        var partes = URLComponents(string: "comgooglemaps://")
        partes?.queryItems = [URLQueryItem(name: "daddr", value: destino(latitud, longitud))]
        return partes?.url
    }

    static func googleWeb(latitud: Double, longitud: Double) -> URL? {
        var partes = URLComponents(string: "https://www.google.com/maps/dir/")
        partes?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: destino(latitud, longitud))
        ]
        return partes?.url
    }

    private static func destino(_ latitud: Double, _ longitud: Double) -> String {
        "\(latitud),\(longitud)"
    }
}
