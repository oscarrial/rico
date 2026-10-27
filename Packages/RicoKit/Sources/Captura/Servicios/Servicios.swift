import Foundation
import RicoCore

/// Un punto del mapa, sin depender de CoreLocation.
public struct Coordenada: Sendable, Hashable {
    public var latitud: Double
    public var longitud: Double

    public init(latitud: Double, longitud: Double) {
        self.latitud = latitud
        self.longitud = longitud
    }

    public func metros(hasta latitud: Double, _ longitud: Double) -> Double {
        DistanciaGeo.metros(self.latitud, self.longitud, latitud, longitud)
    }
}

/// Busca restaurantes con ese nombre alrededor de un punto.
@MainActor
public protocol BuscadorLugaresCercanos {
    func buscar(_ texto: String, cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado]
}

/// Dónde está el iPhone ahora mismo. Devuelve `nil` sin permiso o si tarda demasiado.
@MainActor
public protocol ProveedorUbicacion {
    func ubicacionActual() async -> Coordenada?
}

/// Avisos locales para valorar una visita.
@MainActor
public protocol Notificador {
    /// Programa «¿Qué tal en <sitio>?» para dentro de `retraso` segundos.
    /// - Parameter sitio: `nil` si aún no se sabe dónde fue.
    func programarValoracion(visitaID: UUID, sitio: String?, importe: Importe, retraso: TimeInterval) async
    /// Quita el aviso pendiente de esa visita (ya valorada o descartada).
    func cancelar(visitaID: UUID)
    /// «¿Has comido en <sitio>?» al salir de un restaurante tras una estancia larga.
    func programarEstancia(visitaID: UUID, sitio: String, desde: Date, hasta: Date) async
}

public extension Notificador {
    /// Por defecto no avisa: así los notificadores de prueba no tienen que implementarlo.
    func programarEstancia(visitaID: UUID, sitio: String, desde: Date, hasta: Date) async {}
}
