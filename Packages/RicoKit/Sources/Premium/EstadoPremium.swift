import Foundation
import Observation

/// Estado de la suscripción a Rico Premium.
///
/// La fuente de verdad es siempre la tienda (`Transaction.currentEntitlements`). En
/// `UserDefaults` solo se guarda una copia para no enseñar los límites del plan gratis
/// durante el primer instante tras abrir la app; se corrige en cuanto responde la tienda.
@MainActor
@Observable
public final class EstadoPremium {
    public enum Carga: Equatable, Sendable {
        case cargando
        case listo
        /// La tienda no ha devuelto los planes (sin conexión, sin cuenta o mal configurada).
        case sinProductos
    }

    public private(set) var esPremium: Bool
    public private(set) var productos: [ProductoPremium] = []
    public private(set) var carga: Carga = .cargando
    public private(set) var comprando = false
    public private(set) var restaurando = false

    /// Suscripción vigente en la tienda (`nil` hasta que responde).
    @ObservationIgnored private var suscrito: Bool?
    /// Premium regalado desde el servidor (ver `SesionUsuario.premiumConcedido`).
    @ObservationIgnored private var concedido = false

    @ObservationIgnored private let tienda: any TiendaPremium
    @ObservationIgnored private let cache: UserDefaults?
    @ObservationIgnored private let ahora: @Sendable () -> Date

    static let claveCache = "premium.cacheArranque"

    /// Copia de la suscripción para el código que corre fuera de la interfaz (el atajo de
    /// Apple Pay, que se ejecuta en segundo plano sin acceso al estado de la app).
    public static var premiumEnCache: Bool {
        UserDefaults.standard.bool(forKey: claveCache)
    }

    public init(
        tienda: any TiendaPremium = TiendaStoreKit(),
        cache: UserDefaults? = .standard,
        ahora: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tienda = tienda
        self.cache = cache
        self.ahora = ahora
        esPremium = cache?.bool(forKey: Self.claveCache) ?? false
    }

    public var anual: ProductoPremium? { productos.first { $0.periodo == .anual } }
    public var mensual: ProductoPremium? { productos.first { $0.periodo == .mensual } }

    /// Lo que se ahorra con el plan anual frente a doce meses del mensual, en tanto por cien (0...100).
    public var ahorroAnual: Int? {
        guard let anual, let mensual, mensual.precio > 0 else { return nil }
        let ahorro = 1 - (anual.precio / (mensual.precio * 12))
        let porcentaje = NSDecimalNumber(decimal: ahorro * 100).doubleValue.rounded(.down)
        return porcentaje >= 1 ? Int(porcentaje) : nil
    }

    // MARK: Ciclo de vida

    /// Se llama una vez al arrancar (`.task` en la raíz): comprueba las compras, carga
    /// los planes y escucha las transacciones hasta que se cancela la tarea.
    public func arrancar() async {
        let cambios = tienda.cambios()
        await actualizarDerechos()
        await cargarProductos()
        for await _ in cambios {
            await actualizarDerechos()
        }
    }

    public func cargarProductos() async {
        if productos.isEmpty { carga = .cargando }
        do {
            let encontrados = try await tienda.productos(ids: ProductosPremium.todos)
            productos = encontrados.sorted { $0.periodo == .anual && $1.periodo != .anual }
            carga = productos.isEmpty ? .sinProductos : .listo
        } catch {
            carga = productos.isEmpty ? .sinProductos : .listo
        }
    }

    public func actualizarDerechos() async {
        let derechos = await tienda.derechosActuales()
        let fecha = ahora()
        suscrito = derechos.contains { $0.vigente(en: fecha) }
        recalcular()
    }

    /// Premium regalado a la cuenta con sesión. Se llama al cambiar de sesión.
    public func conceder(_ concedido: Bool) {
        self.concedido = concedido
        recalcular()
    }

    private func recalcular() {
        // Sin respuesta de la tienda todavía, se mantiene la copia del arranque.
        guard let suscrito else {
            if concedido { esPremium = true }
            return
        }
        esPremium = suscrito || concedido
        cache?.set(esPremium, forKey: Self.claveCache)
    }

    // MARK: Acciones

    @discardableResult
    public func comprar(_ producto: ProductoPremium) async throws -> ResultadoCompra {
        comprando = true
        defer { comprando = false }
        let resultado = try await tienda.comprar(producto.id)
        if resultado == .comprado {
            await actualizarDerechos()
        }
        return resultado
    }

    public func restaurar() async throws {
        restaurando = true
        defer { restaurando = false }
        try await tienda.restaurar()
        await actualizarDerechos()
    }
}
