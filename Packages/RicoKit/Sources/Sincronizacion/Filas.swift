import Foundation

/// Tablas de Supabase que se sincronizan, declaradas en el orden de subida
/// (el de las claves externas de `supabase/migrations`).
public enum TablaRemota: String, CaseIterable, Sendable {
    case restaurantes
    /// Antes que `visitas`: `visitas.pago_id` apunta aquí.
    case pagosCapturados = "pagos_capturados"
    case listas
    case visitas
    case platos
    case fotos
    case listaRestaurantes = "lista_restaurantes"
    case aliasComercio = "alias_comercio"

    /// Orden en que se suben los cambios para no romper claves externas.
    public static let ordenSubida: [TablaRemota] = allCases

    /// Columnas de la clave primaria.
    public var columnasClave: [String] {
        self == .listaRestaurantes ? ["lista_id", "restaurante_id"] : ["id"]
    }
}

/// Clave de una fila remota: el id o, en `lista_restaurantes`, el par lista–restaurante.
public struct ClaveFila: Hashable, Sendable, CustomStringConvertible {
    public let valores: [UUID]

    public init(_ valores: UUID...) {
        self.valores = valores
    }

    /// Lee la forma de `texto`.
    public init?(texto: String) {
        let partes = texto.split(separator: "|").map { UUID(uuidString: String($0)) }
        guard !partes.isEmpty, !partes.contains(nil) else { return nil }
        valores = partes.compactMap { $0 }
    }

    /// Ids en minúsculas separados por «|».
    public var texto: String {
        valores.map { $0.uuidString.lowercased() }.joined(separator: "|")
    }

    public var description: String { texto }
}

/// Una fila de una tabla de Supabase, con las columnas en *snake_case* como en las migraciones.
///
/// Al codificar, los opcionales vacíos van como `null` (si no, un upsert no vaciaría un campo
/// borrado en el iPhone) y `actualizado_en` no se envía: lo fija el disparador del servidor.
public protocol FilaRemota: Codable, Sendable, Equatable {
    static var tabla: TablaRemota { get }
    var clave: ClaveFila { get }
    var usuarioID: UUID { get }
    /// Lo pone el servidor; `nil` en las filas construidas en el iPhone.
    var actualizadoEn: Date? { get set }
    var borradoEn: Date? { get set }
}

// MARK: - Filas

public struct RestauranteRemoto: FilaRemota {
    public static let tabla = TablaRemota.restaurantes
    public var id: UUID
    public var usuarioID: UUID
    public var nombre: String
    public var direccion: String?
    public var ciudad: String?
    public var pais: String?
    public var latitud: Double?
    public var longitud: Double?
    public var mapItemID: String?
    public var cocina: String?
    public var rangoPrecio: Int?
    public var telefono: String?
    public var web: String?
    public var silenciado: Bool
    public var creadoEn: Date?
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case nombre, direccion, ciudad, pais, latitud, longitud
        case mapItemID = "map_item_id"
        case cocina
        case rangoPrecio = "rango_precio"
        case telefono, web, silenciado
        case creadoEn = "creado_en"
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(direccion, forKey: .direccion)
        try c.encode(ciudad, forKey: .ciudad)
        try c.encode(pais, forKey: .pais)
        try c.encode(latitud, forKey: .latitud)
        try c.encode(longitud, forKey: .longitud)
        try c.encode(mapItemID, forKey: .mapItemID)
        try c.encode(cocina, forKey: .cocina)
        try c.encode(rangoPrecio, forKey: .rangoPrecio)
        try c.encode(telefono, forKey: .telefono)
        try c.encode(web, forKey: .web)
        try c.encode(silenciado, forKey: .silenciado)
        try c.encodeIfPresent(creadoEn, forKey: .creadoEn)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct PagoRemoto: FilaRemota {
    public static let tabla = TablaRemota.pagosCapturados
    public var id: UUID
    public var usuarioID: UUID
    public var comercioBruto: String
    public var comercioLimpio: String
    public var importeCentimos: Int
    public var divisa: String
    public var tarjeta: String?
    public var fecha: Date
    public var latitud: Double?
    public var longitud: Double?
    public var puntuacionEmparejado: Double?
    public var estado: String
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case comercioBruto = "comercio_bruto"
        case comercioLimpio = "comercio_limpio"
        case importeCentimos = "importe_centimos"
        case divisa, tarjeta, fecha, latitud, longitud
        case puntuacionEmparejado = "puntuacion_emparejado"
        case estado
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(comercioBruto, forKey: .comercioBruto)
        try c.encode(comercioLimpio, forKey: .comercioLimpio)
        try c.encode(importeCentimos, forKey: .importeCentimos)
        try c.encode(divisa, forKey: .divisa)
        try c.encode(tarjeta, forKey: .tarjeta)
        try c.encode(fecha, forKey: .fecha)
        try c.encode(latitud, forKey: .latitud)
        try c.encode(longitud, forKey: .longitud)
        try c.encode(puntuacionEmparejado, forKey: .puntuacionEmparejado)
        try c.encode(estado, forKey: .estado)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct ListaRemota: FilaRemota {
    public static let tabla = TablaRemota.listas
    public var id: UUID
    public var usuarioID: UUID
    public var nombre: String
    public var emoji: String?
    public var tipo: String
    public var orden: Int
    public var compartida: Bool
    public var enlacePublico: String?
    public var creadoEn: Date?
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case nombre, emoji, tipo, orden, compartida
        case enlacePublico = "enlace_publico"
        case creadoEn = "creado_en"
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(tipo, forKey: .tipo)
        try c.encode(orden, forKey: .orden)
        try c.encode(compartida, forKey: .compartida)
        try c.encode(enlacePublico, forKey: .enlacePublico)
        try c.encodeIfPresent(creadoEn, forKey: .creadoEn)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct VisitaRemota: FilaRemota {
    public static let tabla = TablaRemota.visitas
    public var id: UUID
    public var usuarioID: UUID
    public var restauranteID: UUID?
    public var pagoID: UUID?
    public var fecha: Date
    public var estado: String
    public var estrellas: Double?
    public var resena: String?
    public var volveria: String?
    public var importeCentimos: Int?
    public var divisa: String
    public var comensales: Int
    public var pagueTodo: Bool
    public var ocasion: String?
    public var origen: String
    public var creadaPorIA: Bool
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case restauranteID = "restaurante_id"
        case pagoID = "pago_id"
        case fecha, estado, estrellas, resena, volveria
        case importeCentimos = "importe_centimos"
        case divisa, comensales
        case pagueTodo = "pague_todo"
        case ocasion, origen
        case creadaPorIA = "creada_por_ia"
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(restauranteID, forKey: .restauranteID)
        try c.encode(pagoID, forKey: .pagoID)
        try c.encode(fecha, forKey: .fecha)
        try c.encode(estado, forKey: .estado)
        try c.encode(estrellas, forKey: .estrellas)
        try c.encode(resena, forKey: .resena)
        try c.encode(volveria, forKey: .volveria)
        try c.encode(importeCentimos, forKey: .importeCentimos)
        try c.encode(divisa, forKey: .divisa)
        try c.encode(comensales, forKey: .comensales)
        try c.encode(pagueTodo, forKey: .pagueTodo)
        try c.encode(ocasion, forKey: .ocasion)
        try c.encode(origen, forKey: .origen)
        try c.encode(creadaPorIA, forKey: .creadaPorIA)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct PlatoRemoto: FilaRemota {
    public static let tabla = TablaRemota.platos
    public var id: UUID
    public var usuarioID: UUID
    public var visitaID: UUID
    public var nombre: String
    public var valoracion: String?
    public var precioCentimos: Int?
    public var nota: String?
    public var orden: Int
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case visitaID = "visita_id"
        case nombre, valoracion
        case precioCentimos = "precio_centimos"
        case nota, orden
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(visitaID, forKey: .visitaID)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(valoracion, forKey: .valoracion)
        try c.encode(precioCentimos, forKey: .precioCentimos)
        try c.encode(nota, forKey: .nota)
        try c.encode(orden, forKey: .orden)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct FotoRemota: FilaRemota {
    public static let tabla = TablaRemota.fotos
    public var id: UUID
    public var usuarioID: UUID
    public var visitaID: UUID
    public var platoID: UUID?
    public var ruta: String
    public var rutaMiniatura: String
    public var fecha: Date
    public var esComida: Bool
    public var platoSugerido: String?
    public var orden: Int
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case visitaID = "visita_id"
        case platoID = "plato_id"
        case ruta
        case rutaMiniatura = "ruta_miniatura"
        case fecha
        case esComida = "es_comida"
        case platoSugerido = "plato_sugerido"
        case orden
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(visitaID, forKey: .visitaID)
        try c.encode(platoID, forKey: .platoID)
        try c.encode(ruta, forKey: .ruta)
        try c.encode(rutaMiniatura, forKey: .rutaMiniatura)
        try c.encode(fecha, forKey: .fecha)
        try c.encode(esComida, forKey: .esComida)
        try c.encode(platoSugerido, forKey: .platoSugerido)
        try c.encode(orden, forKey: .orden)
        try c.encode(borradoEn, forKey: .borradoEn)
    }

    /// Rutas en el bucket `fotos`: `<usuario>/<foto>.jpg` y `<usuario>/<foto>-mini.jpg`.
    public static func rutas(usuario: UUID, foto: UUID) -> (imagen: String, miniatura: String) {
        let carpeta = usuario.uuidString.lowercased()
        let nombre = foto.uuidString.lowercased()
        return ("\(carpeta)/\(nombre).jpg", "\(carpeta)/\(nombre)-mini.jpg")
    }
}

public struct ListaRestauranteRemota: FilaRemota {
    public static let tabla = TablaRemota.listaRestaurantes
    public var listaID: UUID
    public var restauranteID: UUID
    public var usuarioID: UUID
    /// Solo se lee: el servidor lo pone al crear la fila.
    public var creadoEn: Date?
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(listaID, restauranteID) }

    enum CodingKeys: String, CodingKey {
        case listaID = "lista_id"
        case restauranteID = "restaurante_id"
        case usuarioID = "usuario_id"
        case creadoEn = "creado_en"
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(listaID, forKey: .listaID)
        try c.encode(restauranteID, forKey: .restauranteID)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}

public struct AliasRemoto: FilaRemota {
    public static let tabla = TablaRemota.aliasComercio
    public var id: UUID
    public var usuarioID: UUID
    public var comercioLimpio: String
    public var restauranteID: UUID
    public var vecesConfirmado: Int
    public var actualizadoEn: Date?
    public var borradoEn: Date?

    public var clave: ClaveFila { ClaveFila(id) }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioID = "usuario_id"
        case comercioLimpio = "comercio_limpio"
        case restauranteID = "restaurante_id"
        case vecesConfirmado = "veces_confirmado"
        case actualizadoEn = "actualizado_en"
        case borradoEn = "borrado_en"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(usuarioID, forKey: .usuarioID)
        try c.encode(comercioLimpio, forKey: .comercioLimpio)
        try c.encode(restauranteID, forKey: .restauranteID)
        try c.encode(vecesConfirmado, forKey: .vecesConfirmado)
        try c.encode(borradoEn, forKey: .borradoEn)
    }
}
