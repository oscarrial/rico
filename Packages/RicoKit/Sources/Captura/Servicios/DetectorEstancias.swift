import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftData
import Modelos
import RicoCore
import Visitas

/// Detecta comidas por ubicación con la API de visitas de iOS (`startMonitoringVisits`): gasta muy
/// poca batería porque iOS agrupa las visitas y despierta la app al salir de cada sitio.
///
/// Necesita el permiso de ubicación «Siempre». Se activa desde la guía de captura y se arranca
/// al abrir la app (también cuando iOS la abre en segundo plano para entregar una visita).
@MainActor
@Observable
public final class DetectorEstancias: NSObject, CLLocationManagerDelegate {
    public static let compartido = DetectorEstancias()

    static let claveActivo = "estancias.activo"

    /// El usuario quiere que Rico pregunte tras estar un rato en un restaurante.
    public private(set) var activo = false
    public private(set) var autorizacion: CLAuthorizationStatus = .notDetermined

    /// La base donde guardar las visitas. La pone la app al arrancar (ver `RicoApp`).
    @ObservationIgnored public var contexto: (@MainActor () -> ModelContext)?

    @ObservationIgnored private let gestor = CLLocationManager()
    @ObservationIgnored private let preferencias: UserDefaults

    public init(preferencias: UserDefaults = .standard) {
        self.preferencias = preferencias
        super.init()
        activo = preferencias.bool(forKey: Self.claveActivo)
        autorizacion = gestor.authorizationStatus
        gestor.delegate = self
    }

    /// `true` si de verdad se están vigilando las visitas.
    public var vigilando: Bool { activo && autorizacion == .authorizedAlways }

    /// Al arrancar la app: vuelve a vigilar si estaba activo y hay permiso.
    public func arrancarSiProcede() {
        if vigilando {
            gestor.startMonitoringVisits()
        }
    }

    /// Lo pide el usuario. Si falta el permiso «Siempre», se pide; al concederlo se empieza.
    public func activar() {
        activo = true
        preferencias.set(true, forKey: Self.claveActivo)
        if autorizacion == .authorizedAlways {
            gestor.startMonitoringVisits()
        } else {
            gestor.requestAlwaysAuthorization()
        }
    }

    public func desactivar() {
        activo = false
        preferencias.set(false, forKey: Self.claveActivo)
        gestor.stopMonitoringVisits()
    }

    // MARK: CLLocationManagerDelegate

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let estado = manager.authorizationStatus
        Task { @MainActor in
            self.autorizacion = estado
            if self.vigilando { self.gestor.startMonitoringVisits() }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let estancia = Estancia(
            latitud: visit.coordinate.latitude,
            longitud: visit.coordinate.longitude,
            llegada: visit.arrivalDate,
            salida: visit.departureDate,
            precisionMetros: visit.horizontalAccuracy
        )
        Task { @MainActor in
            await self.procesar(estancia)
        }
    }

    private func procesar(_ estancia: Estancia) async {
        guard activo, let contexto = contexto?() else { return }
        let procesador = ProcesadorEstancias(
            contexto: contexto,
            buscador: BuscadorPuntosCercanosMapKit(),
            notificador: NotificadorLocal()
        )
        await procesador.procesar(estancia)
    }
}

/// Puntos de interés de Apple Maps alrededor de un punto (`MKLocalPointsOfInterestRequest`).
@MainActor
public final class BuscadorPuntosCercanosMapKit: BuscadorPuntosCercanos {
    public init() {}

    public func buscar(cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado] {
        let peticion = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(latitude: cerca.latitud, longitude: cerca.longitud),
            radius: radioMetros
        )
        peticion.pointOfInterestFilter = MKPointOfInterestFilter(
            including: FiltroSitios.restauracion.map(MKPointOfInterestCategory.init(rawValue:))
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
