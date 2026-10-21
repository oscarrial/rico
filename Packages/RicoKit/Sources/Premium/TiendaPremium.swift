import Foundation

/// Identificadores de Rico Premium en App Store Connect (grupo de suscripción «Rico Premium»).
public enum ProductosPremium {
    public static let mensual = "es.rico.app.premium.mensual"
    public static let anual = "es.rico.app.premium.anual"
    public static let todos = [anual, mensual]
}

/// Un plan de Rico Premium tal como lo devuelve la tienda, sin tipos de StoreKit.
public struct ProductoPremium: Identifiable, Hashable, Sendable {
    public enum Periodo: Hashable, Sendable {
        case mensual
        case anual
    }

    public let id: String
    public let periodo: Periodo
    /// Precio ya formateado por la App Store en la moneda del usuario (`displayPrice`).
    public let precioTexto: String
    public let precio: Decimal
    public let formatoPrecio: Decimal.FormatStyle.Currency
    /// Días de prueba gratis si el usuario puede usarla; `nil` si no hay o ya la usó.
    public let diasPrueba: Int?

    public init(
        id: String,
        periodo: Periodo,
        precioTexto: String,
        precio: Decimal,
        formatoPrecio: Decimal.FormatStyle.Currency,
        diasPrueba: Int? = nil
    ) {
        self.id = id
        self.periodo = periodo
        self.precioTexto = precioTexto
        self.precio = precio
        self.formatoPrecio = formatoPrecio
        self.diasPrueba = diasPrueba
    }

    /// Lo que sale al mes, con el formato de la tienda («1,67 €»).
    public var precioMensualTexto: String {
        switch periodo {
        case .mensual: precioTexto
        case .anual: (precio / 12).formatted(formatoPrecio)
        }
    }
}

/// Una compra vigente o pasada que la tienda dice que da acceso.
public struct DerechoPremium: Hashable, Sendable {
    public let productoID: String
    /// La firma de la App Store se ha comprobado.
    public let verificado: Bool
    public let revocadoEn: Date?
    public let caducaEn: Date?

    public init(productoID: String, verificado: Bool, revocadoEn: Date? = nil, caducaEn: Date? = nil) {
        self.productoID = productoID
        self.verificado = verificado
        self.revocadoEn = revocadoEn
        self.caducaEn = caducaEn
    }

    /// Da acceso a Premium en este momento.
    public func vigente(en fecha: Date) -> Bool {
        guard verificado, revocadoEn == nil, ProductosPremium.todos.contains(productoID) else { return false }
        if let caducaEn { return caducaEn > fecha }
        return true
    }
}

public enum ResultadoCompra: Sendable, Equatable {
    case comprado
    /// Espera una aprobación (por ejemplo, «Pedir la compra» en En familia).
    case pendiente
    case cancelado
}

public enum ErrorPremium: Error, Equatable, Sendable {
    case productoNoDisponible
    case compraNoVerificada
    case tienda(String)
}

/// La App Store, detrás de un protocolo para probar `EstadoPremium` sin StoreKit.
public protocol TiendaPremium: Sendable {
    func productos(ids: [String]) async throws -> [ProductoPremium]
    func derechosActuales() async -> [DerechoPremium]
    func comprar(_ id: String) async throws -> ResultadoCompra
    /// Pide a la App Store que vuelva a enviar las compras (`AppStore.sync()`).
    func restaurar() async throws
    /// Avisa cada vez que llega una transacción fuera de la app (renovación, reembolso, otro dispositivo).
    func cambios() -> AsyncStream<Void>
}
