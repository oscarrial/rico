import Foundation

/// Estado de una visita: las detectadas nacen en borrador hasta que el usuario las valora.
public enum EstadoVisita: String, Codable, Sendable, CaseIterable {
    case borrador
    case valorada
    case descartada
}

/// Qué creó la visita.
public enum OrigenVisita: String, Codable, Sendable, CaseIterable {
    case pago
    case ubicacion
    case manual
}

/// «¿Volverías?», independiente de las estrellas.
public enum Volveria: String, Codable, Sendable, CaseIterable {
    case si
    case quiza
    case no
}

/// Nota individual de un plato.
public enum ValoracionPlato: String, Codable, Sendable, CaseIterable {
    case encanto
    case bien
    case noRepetiria
}

public enum TipoLista: String, Codable, Sendable, CaseIterable {
    case quieroProbar
    case propia
}

/// Estado de un pago capturado por el atajo de Apple Pay.
public enum EstadoPago: String, Codable, Sendable, CaseIterable {
    /// Asignado a un restaurante (solo o por alias).
    case asignado
    /// Se propusieron candidatos al usuario.
    case propuesto
    /// Espera en la bandeja a que el usuario elija.
    case pendiente
    /// No es restauración o el usuario dijo «no era un restaurante».
    case descartado
    /// Repetición de un pago ya recibido.
    case duplicado
    /// Filtrado por importe mínimo o tarjeta no vigilada.
    case ignorado
}

/// Límites del plan gratis.
public enum LimitesGratis {
    public static let fotosPorVisita = 3
    public static let listasPropias = 3
}

/// Restaurante escrito a mano, sin pasar por el buscador de mapas (no tiene coordenadas).
public struct RestauranteManual: Sendable, Hashable {
    public var nombre: String
    public var ciudad: String?
    public var direccion: String?

    public init(nombre: String, ciudad: String? = nil, direccion: String? = nil) {
        self.nombre = nombre
        self.ciudad = ciudad
        self.direccion = direccion
    }
}

/// Un lugar devuelto por el buscador de mapas, independiente de MapKit.
public struct LugarEncontrado: Sendable, Hashable, Identifiable {
    public var mapItemID: String?
    public var nombre: String
    public var direccion: String?
    public var ciudad: String?
    public var pais: String?
    public var latitud: Double
    public var longitud: Double
    public var telefono: String?
    public var web: URL?
    public var categoria: String?

    public var id: String { mapItemID ?? "\(nombre)|\(latitud)|\(longitud)" }

    public init(
        mapItemID: String? = nil,
        nombre: String,
        direccion: String? = nil,
        ciudad: String? = nil,
        pais: String? = nil,
        latitud: Double,
        longitud: Double,
        telefono: String? = nil,
        web: URL? = nil,
        categoria: String? = nil
    ) {
        self.mapItemID = mapItemID
        self.nombre = nombre
        self.direccion = direccion
        self.ciudad = ciudad
        self.pais = pais
        self.latitud = latitud
        self.longitud = longitud
        self.telefono = telefono
        self.web = web
        self.categoria = categoria
    }
}
