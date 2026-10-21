import Foundation
import SwiftData
import Modelos

/// Bases locales abiertas por la app, una por cuenta. La app y la acción de Atajos
/// («Registrar pago») usan el mismo contenedor, así lo que guarda el atajo aparece al momento.
@MainActor
enum AlmacenApp {
    private static var abiertos: [String: ModelContainer] = [:]
    private static let claveUsuario = "usuarioActivo"

    /// Cuenta cuya base estaba abierta la última vez (`nil` = modo sin cuenta).
    /// La acción de Atajos guarda los pagos ahí aunque la app no esté abierta.
    static var usuarioGuardado: UUID? {
        get { UserDefaults.standard.string(forKey: claveUsuario).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: claveUsuario) }
    }

    /// Abre (o reutiliza) la base local de esa cuenta.
    static func contenedor(usuario: UUID?) -> ModelContainer {
        let clave = ContenedorRico.nombreAlmacen(usuario: usuario)
        if let abierto = abiertos[clave] { return abierto }
        let nuevo = abrir(usuario: usuario)
        abiertos[clave] = nuevo
        return nuevo
    }

    private static func abrir(usuario: UUID?) -> ModelContainer {
        do {
            return try ContenedorRico.crear(usuario: usuario)
        } catch {
            // Sin firma (simulador de CI) no hay App Group: base local de la app.
            Registro.datos.notice("Sin App Group (\(String(describing: error), privacy: .public)); se usa el almacenamiento de la app.")
            do {
                return try ContenedorRico.crear(usuario: usuario, usarGrupo: false)
            } catch {
                fatalError("No se pudo abrir la base de datos: \(error)")
            }
        }
    }
}
