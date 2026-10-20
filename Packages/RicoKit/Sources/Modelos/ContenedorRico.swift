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

    /// App Group compartido con las extensiones (atajos, notificaciones), leído del Info.plist.
    public static var identificadorGrupo: String? {
        Bundle.main.object(forInfoDictionaryKey: "RicoAppGroup") as? String
    }

    /// Base local del iPhone. La sincronización con el servidor va aparte (Supabase).
    /// - Parameters:
    ///   - enMemoria: para pruebas y previsualizaciones.
    ///   - usarGrupo: guardar en el App Group. Sin firma (simulador de CI) no existe.
    public static func crear(enMemoria: Bool = false, usarGrupo: Bool = true) throws -> ModelContainer {
        let configuracion: ModelConfiguration
        if enMemoria {
            configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let grupo: ModelConfiguration.GroupContainer = usarGrupo
                ? identificadorGrupo.map { .identifier($0) } ?? .none
                : .none
            configuracion = ModelConfiguration(schema: esquema, groupContainer: grupo, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: esquema, configurations: configuracion)
    }

    /// Borra todos los datos locales (al borrar la cuenta).
    public static func borrarTodo(en contexto: ModelContext) throws {
        try contexto.delete(model: Foto.self)
        try contexto.delete(model: Plato.self)
        try contexto.delete(model: AliasComercio.self)
        try contexto.delete(model: Visita.self)
        try contexto.delete(model: PagoCapturado.self)
        try contexto.delete(model: Lista.self)
        try contexto.delete(model: Restaurante.self)
        try contexto.save()
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
