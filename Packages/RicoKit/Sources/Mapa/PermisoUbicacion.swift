import CoreLocation
import Observation

/// Permiso de ubicación «mientras se usa la app». Solo se pide al pulsar el botón de centrar.
@MainActor
@Observable
final class PermisoUbicacion: NSObject, CLLocationManagerDelegate {
    private(set) var estado: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let gestor = CLLocationManager()

    override init() {
        super.init()
        gestor.delegate = self
        estado = gestor.authorizationStatus
    }

    var permitida: Bool {
        estado == .authorizedWhenInUse || estado == .authorizedAlways
    }

    var sinDecidir: Bool { estado == .notDetermined }

    func pedir() {
        gestor.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let nuevo = manager.authorizationStatus
        Task { @MainActor in
            self.estado = nuevo
        }
    }
}
