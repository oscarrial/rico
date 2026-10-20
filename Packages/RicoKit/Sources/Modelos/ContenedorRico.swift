import Foundation
import SwiftData
import RicoCore

public enum ContenedorRico {
    public static let esquema = Schema([
        Restaurante.self,
        Visita.self,
        Plato.self,
        Foto.self,
        Lista.self,
        PagoCapturado.self,
        AliasComercio.self
    ])

    /// Contenedor de iCloud y App Group, leídos del Info.plist (se fijan en project.yml).
    public static var identificadorICloud: String? {
        Bundle.main.object(forInfoDictionaryKey: "RicoICloudContainer") as? String
    }

    public static var identificadorGrupo: String? {
        Bundle.main.object(forInfoDictionaryKey: "RicoAppGroup") as? String
    }

    /// - Parameters:
    ///   - enMemoria: para pruebas y previsualizaciones; sin iCloud ni App Group.
    ///   - sinNube: base local sin sincronizar, para builds sin firma.
    public static func crear(enMemoria: Bool = false, sinNube: Bool = false) throws -> ModelContainer {
        let configuracion: ModelConfiguration
        if enMemoria {
            configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if sinNube {
            configuracion = ModelConfiguration(schema: esquema, groupContainer: .none, cloudKitDatabase: .none)
        } else {
            configuracion = ModelConfiguration(
                schema: esquema,
                groupContainer: identificadorGrupo.map { .identifier($0) } ?? .automatic,
                cloudKitDatabase: identificadorICloud.map { .private($0) } ?? .automatic
            )
        }
        return try ModelContainer(for: esquema, configurations: configuracion)
    }
}

public extension ModelContext {
    /// Devuelve el restaurante de ese lugar o lo crea. Busca por `mapItemID` y, si no hay,
    /// por nombre a menos de 50 m.
    func restaurante(para lugar: LugarEncontrado) throws -> Restaurante {
        if let mapItemID = lugar.mapItemID {
            let id: String? = mapItemID
            var porID = FetchDescriptor<Restaurante>(predicate: #Predicate { $0.mapItemID == id })
            porID.fetchLimit = 1
            if let existente = try fetch(porID).first { return existente }
        }

        let nombre = lugar.nombre
        let porNombre = FetchDescriptor<Restaurante>(predicate: #Predicate { $0.nombre == nombre })
        if let existente = try fetch(porNombre).first(where: { r in
            guard let lat = r.latitud, let lon = r.longitud else { return false }
            return DistanciaGeo.metros(lat, lon, lugar.latitud, lugar.longitud) < 50
        }) {
            if existente.mapItemID == nil { existente.mapItemID = lugar.mapItemID }
            return existente
        }

        let nuevo = Restaurante(nombre: lugar.nombre)
        nuevo.mapItemID = lugar.mapItemID
        nuevo.direccion = lugar.direccion
        nuevo.ciudad = lugar.ciudad
        nuevo.pais = lugar.pais
        nuevo.latitud = lugar.latitud
        nuevo.longitud = lugar.longitud
        nuevo.telefono = lugar.telefono
        nuevo.web = lugar.web
        insert(nuevo)
        return nuevo
    }
}
