import Foundation
import MapKit
import Observation
import RicoCore

/// Busca sitios para comer en una zona del mapa. Protocolo para poder probar con datos falsos.
@MainActor
public protocol BuscadorCercanos {
    func buscar(en zona: ZonaMapa) async throws -> [LugarEncontrado]
}

/// Búsqueda con Apple Maps (`MKLocalPointsOfInterestRequest`): sin coste por consulta.
@MainActor
public final class BuscadorCercanosMapKit: BuscadorCercanos {
    private var busquedaActual: MKLocalSearch?

    public init() {}

    public func buscar(en zona: ZonaMapa) async throws -> [LugarEncontrado] {
        let limitada = zona.limitada()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: limitada.latitud, longitude: limitada.longitud),
            span: MKCoordinateSpan(latitudeDelta: limitada.latitudDelta, longitudeDelta: limitada.longitudDelta)
        )
        let peticion = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        peticion.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket
        ])

        busquedaActual?.cancel()
        let busqueda = MKLocalSearch(request: peticion)
        busquedaActual = busqueda

        return try await withCheckedThrowingContinuation { continuacion in
            busqueda.start { respuesta, error in
                if let error {
                    continuacion.resume(throwing: error)
                } else {
                    continuacion.resume(returning: (respuesta?.mapItems ?? []).compactMap(Self.lugar))
                }
            }
        }
    }

    nonisolated static func lugar(_ item: MKMapItem) -> LugarEncontrado? {
        guard let nombre = item.name else { return nil }
        let marca = item.placemark
        var identificador: String?
        if #available(iOS 18.0, *) {
            identificador = item.identifier?.rawValue
        }
        let calle = [marca.thoroughfare, marca.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        return LugarEncontrado(
            mapItemID: identificador,
            nombre: nombre,
            direccion: calle.isEmpty ? nil : calle,
            ciudad: marca.locality,
            pais: marca.country,
            latitud: marca.coordinate.latitude,
            longitud: marca.coordinate.longitude,
            telefono: item.phoneNumber,
            web: item.url
        )
    }
}

/// Estado de «Explorar zona»: qué se ha buscado y qué ha salido.
@MainActor
@Observable
public final class ExploradorZona {
    public enum Estado: Equatable, Sendable {
        case inactivo
        case buscando
        case listo
        case error
    }

    public private(set) var lugares: [LugarEncontrado] = []
    public private(set) var estado: Estado = .inactivo
    /// La última zona buscada, para saber si el mapa se ha movido desde entonces.
    public private(set) var zonaBuscada: ZonaMapa?

    @ObservationIgnored private let buscador: any BuscadorCercanos
    /// Solo cuenta la respuesta de la última búsqueda.
    @ObservationIgnored private var peticion = 0

    public init(buscador: any BuscadorCercanos) {
        self.buscador = buscador
    }

    public convenience init() {
        self.init(buscador: BuscadorCercanosMapKit())
    }

    public func explorar(_ zona: ZonaMapa) async {
        peticion += 1
        let esta = peticion
        estado = .buscando
        zonaBuscada = zona
        do {
            let encontrados = try await buscador.buscar(en: zona)
            guard esta == peticion else { return }
            var vistos: Set<String> = []
            lugares = encontrados.filter { vistos.insert($0.id).inserted }
            estado = .listo
        } catch {
            guard esta == peticion else { return }
            lugares = []
            estado = .error
        }
    }

    /// Al volver a «Mis sitios».
    public func limpiar() {
        peticion += 1
        lugares = []
        estado = .inactivo
        zonaBuscada = nil
    }
}
