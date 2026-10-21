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

    /// Nombre del archivo de la base local: uno por cuenta; «Rico» para el modo sin cuenta.
    public static func nombreAlmacen(usuario: UUID?) -> String {
        guard let usuario else { return "Rico" }
        return "Rico-\(usuario.uuidString.lowercased())"
    }

    /// Carpeta de las bases locales: el App Group si existe; si no, Application Support de la app.
    public static func carpetaAlmacenes(usarGrupo: Bool = true) -> URL {
        if usarGrupo, let grupo = identificadorGrupo,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grupo) {
            return url.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory
    }

    /// Base local del iPhone: un archivo por cuenta. La sincronización con el servidor va aparte (Supabase).
    /// - Parameters:
    ///   - enMemoria: para pruebas y previsualizaciones.
    ///   - usuario: cuenta dueña de la base; `nil` para el modo sin cuenta.
    ///   - usarGrupo: guardar en el App Group. Sin firma (simulador de CI) no existe.
    ///   - carpeta: carpeta de los archivos (para pruebas).
    public static func crear(enMemoria: Bool = false, usuario: UUID? = nil, usarGrupo: Bool = true, carpeta: URL? = nil) throws -> ModelContainer {
        if enMemoria {
            let configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: esquema, configurations: configuracion)
        }
        let base = carpeta ?? carpetaAlmacenes(usarGrupo: usarGrupo)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appending(path: "\(nombreAlmacen(usuario: usuario)).store")
        let configuracion = ModelConfiguration(schema: esquema, url: url, cloudKitDatabase: .none)
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

    /// Devuelve el restaurante escrito a mano o lo crea. Reutiliza uno con el mismo nombre
    /// y la misma ciudad (sin distinguir mayúsculas ni tildes).
    func restaurante(manual datos: RestauranteManual) throws -> Restaurante {
        let nombre = datos.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let ciudad = datos.ciudad?.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacia
        let direccion = datos.direccion?.trimmingCharacters(in: .whitespacesAndNewlines).nilSiVacia

        let todos = try fetch(FetchDescriptor<Restaurante>())
        if let existente = todos.first(where: { r in
            r.nombre.compare(nombre, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && (r.ciudad ?? "").compare(ciudad ?? "", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            if existente.direccion == nil { existente.direccion = direccion }
            return existente
        }

        let nuevo = Restaurante(nombre: nombre)
        nuevo.ciudad = ciudad
        nuevo.direccion = direccion
        insert(nuevo)
        return nuevo
    }
}

private extension String {
    var nilSiVacia: String? { isEmpty ? nil : self }
}
