import Foundation
import MapKit
import Observation
import RicoCore

/// Busca sitios para comer en una zona del mapa. Protocolo para poder probar con datos falsos.
@MainActor
public protocol BuscadorCercanos {
    func buscar(en zona: ZonaMapa, tipos: Set<TipoSitio>) async throws -> [LugarEncontrado]
}

/// Búsqueda con Apple Maps (`MKLocalPointsOfInterestRequest`): sin coste por consulta.
@MainActor
public final class BuscadorCercanosMapKit: BuscadorCercanos {
    private var busquedaActual: MKLocalSearch?

    public init() {}

    public func buscar(en zona: ZonaMapa, tipos: Set<TipoSitio>) async throws -> [LugarEncontrado] {
        let limitada = zona.limitada()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: limitada.latitud, longitude: limitada.longitud),
            span: MKCoordinateSpan(latitudeDelta: limitada.latitudDelta, longitudeDelta: limitada.longitudDelta)
        )
        let peticion = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        // Sin tiendas de comida: Apple Maps llama «foodMarket» a supermercados y ultramarinos.
        let categorias = FiltroSitios.categorias(de: tipos).map(MKPointOfInterestCategory.init(rawValue:))
        peticion.pointOfInterestFilter = MKPointOfInterestFilter(including: categorias)

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
            web: item.url,
            categoria: item.pointOfInterestCategory?.rawValue
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
    /// Qué se busca. Por defecto, solo sitios para comer.
    public var tipos: Set<TipoSitio> = [.comer]

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
            let pedidos = tipos
            let encontrados = try await buscador.buscar(en: zona, tipos: pedidos)
            guard esta == peticion else { return }
            // Segundo filtro por nombre: hay tiendas que Apple Maps clasifica como restaurante.
            let permitidas = FiltroSitios.categorias(de: pedidos)
            var vistos: Set<String> = []
            lugares = encontrados.filter {
                FiltroSitios.esValido(nombre: $0.nombre, categoria: $0.categoria, permitidas: permitidas)
                    && vistos.insert($0.id).inserted
            }
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
