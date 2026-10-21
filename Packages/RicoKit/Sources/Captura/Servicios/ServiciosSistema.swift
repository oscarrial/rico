import CoreLocation
import Foundation
import MapKit
import Modelos
import RicoCore
import Visitas

/// Búsqueda con Apple Maps limitada a una zona alrededor del pago.
@MainActor
public final class BuscadorCercanoMapKit: BuscadorLugaresCercanos {
    public init() {}

    public func buscar(_ texto: String, cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado] {
        let consulta = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard consulta.count >= 2 else { return [] }

        let peticion = MKLocalSearch.Request()
        peticion.naturalLanguageQuery = consulta
        peticion.resultTypes = .pointOfInterest
        peticion.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket
        ])
        peticion.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: cerca.latitud, longitude: cerca.longitud),
            latitudinalMeters: radioMetros * 2,
            longitudinalMeters: radioMetros * 2
        )

        let busqueda = MKLocalSearch(request: peticion)
        return try await withCheckedThrowingContinuation { continuacion in
            busqueda.start { respuesta, error in
                if let error {
                    continuacion.resume(throwing: error)
                } else {
                    continuacion.resume(returning: (respuesta?.mapItems ?? []).compactMap(BuscadorMapKit.lugar))
                }
            }
        }
    }
}

/// Ubicación actual con CoreLocation. Nunca pide permiso: si no lo hay, devuelve `nil`.
@MainActor
public final class UbicacionCoreLocation: ProveedorUbicacion {
    private let limite: Duration
    private let antiguedadMaxima: TimeInterval

    /// - Parameters:
    ///   - limite: tiempo máximo esperando una lectura nueva.
    ///   - antiguedadMaxima: una lectura guardada más reciente que esto se usa sin esperar.
    public init(limite: Duration = .seconds(4), antiguedadMaxima: TimeInterval = 10 * 60) {
        self.limite = limite
        self.antiguedadMaxima = antiguedadMaxima
    }

    public func ubicacionActual() async -> Coordenada? {
        let gestor = CLLocationManager()
        switch gestor.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        default: return nil
        }
        if let ultima = gestor.location, abs(ultima.timestamp.timeIntervalSinceNow) < antiguedadMaxima {
            return Coordenada(latitud: ultima.coordinate.latitude, longitud: ultima.coordinate.longitude)
        }
        return await Self.primeraLectura(limite: limite)
    }

    nonisolated private static func primeraLectura(limite: Duration) async -> Coordenada? {
        await withTaskGroup(of: Coordenada?.self) { grupo in
            grupo.addTask {
                do {
                    for try await lectura in CLLocationUpdate.liveUpdates() {
                        if let lugar = lectura.location {
                            return Coordenada(latitud: lugar.coordinate.latitude, longitud: lugar.coordinate.longitude)
                        }
                    }
                } catch {
                    Registro.captura.notice("Sin ubicación: \(String(describing: error), privacy: .public)")
                }
                return nil
            }
            grupo.addTask {
                try? await Task.sleep(for: limite)
                return nil
            }
            let primera = await grupo.next() ?? nil
            grupo.cancelAll()
            return primera
        }
    }
}
