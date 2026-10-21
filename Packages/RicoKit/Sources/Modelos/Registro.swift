import os

/// Registros de la app (Consola de macOS o `log stream` con el iPhone conectado).
public enum Registro {
    public static let subsistema = "es.rico.app"
    public static let cuenta = Logger(subsystem: subsistema, category: "cuenta")
    public static let datos = Logger(subsystem: subsistema, category: "datos")
    public static let fotos = Logger(subsystem: subsistema, category: "fotos")
    public static let busqueda = Logger(subsystem: subsistema, category: "busqueda")
}
