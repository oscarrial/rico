import Foundation

/// El servidor de la sincronización. Protocolo para poder probar con un servidor falso.
///
/// Todas las filas pertenecen al usuario con sesión (RLS «solo el dueño»).
public protocol ServicioSincronizacion: Sendable {
    /// Crea o actualiza las filas (upsert por clave primaria, con `borrado_en` a `null`)
    /// y devuelve el `actualizado_en` que les ha puesto el servidor.
    func subir<F: FilaRemota>(_ filas: [F]) async throws -> [ClaveFila: Date]

    /// Borrado lógico: pone `borrado_en` en esas filas. Devuelve su nuevo `actualizado_en`
    /// (las que no existen en el servidor no aparecen).
    func marcarBorradas<F: FilaRemota>(_ tipo: F.Type, claves: [ClaveFila], fecha: Date) async throws -> [ClaveFila: Date]

    /// Filas cambiadas después de `cambiadasDesde`, por `actualizado_en` ascendente, incluidas
    /// las borradas. Con `cambiadasDesde == nil` (primera vez) devuelve solo las no borradas.
    func bajar<F: FilaRemota>(_ tipo: F.Type, cambiadasDesde: Date?, posicion: Int, limite: Int) async throws -> [F]

    /// Sube un JPEG al bucket privado `fotos` (sobrescribe si ya existe).
    func subirImagen(_ datos: Data, ruta: String) async throws

    func bajarImagen(ruta: String) async throws -> Data

    func borrarImagenes(rutas: [String]) async throws
}

/// El servidor no responde (sin red o caído): se para la vuelta y se reintenta más tarde.
/// Cualquier otro error se toma como un problema de esas filas concretas.
func esErrorDeConexion(_ error: any Error) -> Bool {
    if error is URLError { return true }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain
}
