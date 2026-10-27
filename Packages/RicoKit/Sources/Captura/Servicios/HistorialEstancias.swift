import Foundation
import Modelos
import RicoCore

/// Lo que la detección por ubicación recuerda de una estancia a otra: dónde has dormido estos
/// días (para no preguntar por el bar de debajo del hotel) y los sitios por los que dijiste que
/// no habías comido. Se queda en el iPhone (UserDefaults) y no se sincroniza.
public struct HistorialEstancias {
    static let claveNoches = "estancias.noches"
    static let claveSilenciados = "estancias.silenciados"
    /// Cuánto se recuerdan los sitios donde se ha dormido.
    static let memoriaNoches: TimeInterval = 30 * 24 * 3600
    /// Tope de noches guardadas, para que no crezca sin límite.
    static let maximoNoches = 60

    private let preferencias: UserDefaults

    public init(preferencias: UserDefaults = .standard) {
        self.preferencias = preferencias
    }

    /// Sitios donde se ha dormido en el último mes.
    public func noches(ahora: Date = .now) -> [LugarDormido] {
        guard
            let datos = preferencias.data(forKey: Self.claveNoches),
            let guardadas = try? JSONDecoder().decode([LugarDormido].self, from: datos)
        else { return [] }
        return guardadas.filter { ahora.timeIntervalSince($0.fecha) < Self.memoriaNoches }
    }

    public func anotarNoche(_ lugar: LugarDormido) {
        var todas = noches(ahora: lugar.fecha)
        todas.append(lugar)
        let recientes = Array(todas.suffix(Self.maximoNoches))
        if let datos = try? JSONEncoder().encode(recientes) {
            preferencias.set(datos, forKey: Self.claveNoches)
        }
    }

    /// Ids de Apple Maps (o el id sintético de `LugarEncontrado`) por los que no se vuelve a preguntar.
    public var silenciados: Set<String> {
        Set(preferencias.stringArray(forKey: Self.claveSilenciados) ?? [])
    }

    public func silenciar(_ id: String) {
        var todos = silenciados
        todos.insert(id)
        preferencias.set(Array(todos), forKey: Self.claveSilenciados)
    }

    /// El mismo id que tenía el sitio de Apple Maps del que salió el restaurante (`LugarEncontrado.id`).
    public static func idLugar(de restaurante: Restaurante) -> String? {
        if let mapItemID = restaurante.mapItemID { return mapItemID }
        guard let latitud = restaurante.latitud, let longitud = restaurante.longitud else { return nil }
        return "\(restaurante.nombre)|\(latitud)|\(longitud)"
    }
}
