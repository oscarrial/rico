import Foundation
import SwiftData

// Estado de la sincronización con el servidor, guardado en la misma base que los datos
// (una por cuenta). Solo lo usa el módulo `Sincronizacion`; las pantallas no lo leen.
// Ver docs/decisiones/0004-sincronizacion.md.

/// Lo último que se sabe de una fila del servidor y si tiene cambios locales sin subir.
@Model
public final class RegistroSincronizado {
    /// Tabla de Supabase (`visitas`, `lista_restaurantes`…).
    public var tabla: String = ""
    /// Clave de la fila: el id en minúsculas o, en `lista_restaurantes`, «lista|restaurante».
    public var clave: String = ""
    /// Huella del contenido que tiene el servidor. `nil`: la fila nunca se ha subido.
    public var huella: String?
    /// `actualizado_en` de la última versión del servidor que se conoce.
    public var actualizadoEnServidor: Date?
    /// Cuándo se vio por primera vez un cambio local sin subir (`nil` si no hay).
    public var cambiadoEnLocal: Date?
    /// Cuándo se vio que la fila ya no está en el iPhone: borrado pendiente de subir.
    public var borradoEnLocal: Date?

    public init(tabla: String, clave: String) {
        self.tabla = tabla
        self.clave = clave
    }

    /// Hay algo que subir: un cambio o un borrado.
    public var pendiente: Bool { cambiadoEnLocal != nil || borradoEnLocal != nil }
}

/// Hasta dónde se han bajado los cambios de una tabla (`actualizado_en` más reciente visto).
@Model
public final class MarcaBajada {
    public var tabla: String = ""
    public var fecha: Date?

    public init(tabla: String, fecha: Date? = nil) {
        self.tabla = tabla
        self.fecha = fecha
    }
}
