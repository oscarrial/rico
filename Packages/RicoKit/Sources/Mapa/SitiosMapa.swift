import Foundation
import SwiftData
import Modelos
import RicoCore

/// Color del pin de un sitio. Ver DESIGN.md § Color (pines del mapa).
public enum CategoriaPin: Equatable, Sendable {
    /// Nota media de 4,5 o más.
    case top
    /// De 3,5 a 4,4.
    case bien
    /// Menos de 3,5.
    case normal
    /// En «Quiero probar» y todavía sin visitas.
    case quieroProbar
    /// Encontrado con «Explorar zona».
    case explorar

    /// La nota se redondea a una cifra decimal antes, para que el color coincida con la nota que se lee.
    public static func porNota(_ nota: Double) -> CategoriaPin {
        let redondeada = (nota * 10).rounded() / 10
        if redondeada >= 4.5 { return .top }
        if redondeada >= 3.5 { return .bien }
        return .normal
    }
}

/// Un restaurante tuyo en el mapa.
public struct PinRestaurante: Identifiable {
    public let id: UUID
    public let restaurante: Restaurante
    public let latitud: Double
    public let longitud: Double
    /// Nota media de las visitas valoradas; `nil` en «Quiero probar».
    public let nota: Double?
    public let categoria: CategoriaPin
}

/// Qué sale en el mapa de «Mis sitios».
@MainActor
public enum SitiosMapa {
    /// Restaurantes con coordenadas y al menos una visita valorada, más los de «Quiero probar»
    /// que aún no tienen visitas. Los dados de alta a mano (sin coordenadas) no salen.
    /// - Parameter quieroProbar: ids de los restaurantes que están en alguna lista «Quiero probar».
    public static func pines(_ restaurantes: [Restaurante], quieroProbar: Set<UUID>) -> [PinRestaurante] {
        restaurantes.compactMap { restaurante in
            guard let latitud = restaurante.latitud, let longitud = restaurante.longitud else { return nil }
            let valoradas = (restaurante.visitas ?? []).filter { $0.estado == .valorada }
            let notas = valoradas.compactMap(\.estrellas)
            if !notas.isEmpty {
                let media = notas.reduce(0, +) / Double(notas.count)
                return PinRestaurante(
                    id: restaurante.id,
                    restaurante: restaurante,
                    latitud: latitud,
                    longitud: longitud,
                    nota: media,
                    categoria: .porNota(media)
                )
            }
            if valoradas.isEmpty, quieroProbar.contains(restaurante.id) {
                return PinRestaurante(
                    id: restaurante.id,
                    restaurante: restaurante,
                    latitud: latitud,
                    longitud: longitud,
                    nota: nil,
                    categoria: .quieroProbar
                )
            }
            return nil
        }
    }

    /// Ids de los restaurantes guardados en las listas «Quiero probar».
    public static func idsQuieroProbar(_ listas: [Lista]) -> Set<UUID> {
        Set(listas.filter { $0.tipo == .quieroProbar }.flatMap { ($0.restaurantes ?? []).map(\.id) })
    }

    /// Quita de «Explorar zona» los sitios repetidos y los que ya son pines tuyos
    /// (mismo identificador de Apple Maps, o mismo nombre a menos de 50 m).
    public static func sinRepetir(_ lugares: [LugarEncontrado], pines: [PinRestaurante]) -> [LugarEncontrado] {
        let conocidos = pines.map { pin in
            (mapItemID: pin.restaurante.mapItemID, nombre: pin.restaurante.nombre, latitud: pin.latitud, longitud: pin.longitud)
        }
        var vistos: Set<String> = []
        return lugares.filter { lugar in
            guard vistos.insert(lugar.id).inserted else { return false }
            return !conocidos.contains { conocido in
                if let id = lugar.mapItemID, id == conocido.mapItemID { return true }
                return conocido.nombre.compare(lugar.nombre, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                    && DistanciaGeo.metros(conocido.latitud, conocido.longitud, lugar.latitud, lugar.longitud) < 50
            }
        }
    }
}

/// Zona del mapa, independiente de MapKit para poder probarla.
public struct ZonaMapa: Equatable, Sendable {
    public var latitud: Double
    public var longitud: Double
    public var latitudDelta: Double
    public var longitudDelta: Double

    public init(latitud: Double, longitud: Double, latitudDelta: Double, longitudDelta: Double) {
        self.latitud = latitud
        self.longitud = longitud
        self.latitudDelta = latitudDelta
        self.longitudDelta = longitudDelta
    }

    /// La zona que encuadra todos los puntos con un margen alrededor; `nil` si no hay puntos.
    public static func encuadrando(
        _ puntos: [(latitud: Double, longitud: Double)],
        margen: Double = 1.4,
        deltaMinimo: Double = 0.01
    ) -> ZonaMapa? {
        guard let primero = puntos.first else { return nil }
        var minLat = primero.latitud, maxLat = primero.latitud
        var minLon = primero.longitud, maxLon = primero.longitud
        for punto in puntos.dropFirst() {
            minLat = min(minLat, punto.latitud)
            maxLat = max(maxLat, punto.latitud)
            minLon = min(minLon, punto.longitud)
            maxLon = max(maxLon, punto.longitud)
        }
        return ZonaMapa(
            latitud: (minLat + maxLat) / 2,
            longitud: (minLon + maxLon) / 2,
            latitudDelta: min(180, max(deltaMinimo, (maxLat - minLat) * margen)),
            longitudDelta: min(360, max(deltaMinimo, (maxLon - minLon) * margen))
        )
    }

    /// La misma zona, recortada alrededor del centro para que la búsqueda de sitios cercanos
    /// no pida una ciudad entera.
    public func limitada(a maximo: Double = 0.08) -> ZonaMapa {
        ZonaMapa(
            latitud: latitud,
            longitud: longitud,
            latitudDelta: min(latitudDelta, maximo),
            longitudDelta: min(longitudDelta, maximo)
        )
    }
}

public extension ModelContext {
    /// Guarda el lugar en «Quiero probar» sin duplicarlo y reutilizando el restaurante si ya existe.
    /// - Returns: el restaurante y si se ha añadido ahora (`false` si ya estaba).
    @discardableResult
    func anadirAQuieroProbar(_ lugar: LugarEncontrado) throws -> (restaurante: Restaurante, anadido: Bool) {
        let sitio = try self.restaurante(para: lugar)
        let lista = try listaQuieroProbar()
        if lista.contiene(sitio) {
            return (sitio, false)
        }
        try anadir(sitio, a: lista)
        return (sitio, true)
    }
}
