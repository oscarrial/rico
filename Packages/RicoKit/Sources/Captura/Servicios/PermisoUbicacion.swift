import CoreLocation
import Foundation
import Observation

/// Permiso de ubicación «Al usar la app», para reconocer el restaurante donde se paga.
@MainActor
@Observable
public final class PermisoUbicacion: NSObject, CLLocationManagerDelegate {
    public private(set) var estado: EstadoPermiso = .sinPreguntar

    @ObservationIgnored private let gestor = CLLocationManager()

    public override init() {
        super.init()
        gestor.delegate = self
        estado = Self.traducir(gestor.authorizationStatus)
    }

    public func pedir() {
        gestor.requestWhenInUseAuthorization()
    }

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let estado = Self.traducir(manager.authorizationStatus)
        Task { @MainActor in
            self.estado = estado
        }
    }

    private nonisolated static func traducir(_ estado: CLAuthorizationStatus) -> EstadoPermiso {
        switch estado {
        case .authorizedWhenInUse, .authorizedAlways: .concedido
        case .denied, .restricted: .denegado
        case .notDetermined: .sinPreguntar
        @unknown default: .sinPreguntar
        }
    }
}
