import Foundation
import MapKit
import RicoCore

/// Busca restaurantes por nombre. Protocolo para poder probar con datos falsos.
@MainActor
public protocol BuscadorLugares {
    func buscar(_ texto: String) async throws -> [LugarEncontrado]
}

/// Búsqueda con Apple Maps (`MKLocalSearch`): sin coste por consulta.
@MainActor
public final class BuscadorMapKit: BuscadorLugares {
    private var busquedaActual: MKLocalSearch?

    public init() {}

    public func buscar(_ texto: String) async throws -> [LugarEncontrado] {
        let consulta = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard consulta.count >= 2 else { return [] }

        let peticion = MKLocalSearch.Request()
        peticion.naturalLanguageQuery = consulta
        peticion.resultTypes = .pointOfInterest
        peticion.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket
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

    public nonisolated static func lugar(_ item: MKMapItem) -> LugarEncontrado? {
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
