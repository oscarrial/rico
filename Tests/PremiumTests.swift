import Foundation
import Testing
import Premium

/// App Store de mentira: devuelve los planes y las compras que se le digan.
actor TiendaFalsa: TiendaPremium {
    var planes: [ProductoPremium]
    var derechos: [DerechoPremium] = []
    var errorProductos = false
    /// Lo que se apunta como derecho al comprar (o `nil` si la compra se cancela).
    var derechoAlComprar: (String) -> DerechoPremium? = { DerechoPremium(productoID: $0, verificado: true, caducaEn: .distantFuture) }
    private(set) var restauraciones = 0

    nonisolated let flujo: AsyncStream<Void>
    nonisolated let continuacion: AsyncStream<Void>.Continuation

    init(planes: [ProductoPremium] = TiendaFalsa.planesDePrueba) {
        self.planes = planes
        let (flujo, continuacion) = AsyncStream<Void>.makeStream()
        self.flujo = flujo
        self.continuacion = continuacion
    }

    static let planesDePrueba = [
        ProductoPremium(id: ProductosPremium.mensual, periodo: .mensual, precioTexto: "2,99 €", precio: Decimal(string: "2.99")!, formatoPrecio: .currency(code: "EUR")),
        ProductoPremium(id: ProductosPremium.anual, periodo: .anual, precioTexto: "19,99 €", precio: Decimal(string: "19.99")!, formatoPrecio: .currency(code: "EUR"), diasPrueba: 7)
    ]

    func poner(derechos: [DerechoPremium]) { self.derechos = derechos }
    func fallarProductos() { errorProductos = true }
    func cancelarCompras() { derechoAlComprar = { _ in nil } }

    func productos(ids: [String]) async throws -> [ProductoPremium] {
        if errorProductos { throw ErrorPremium.tienda("sin conexión") }
        return planes.filter { ids.contains($0.id) }
    }

    func derechosActuales() async -> [DerechoPremium] { derechos }

    func comprar(_ id: String) async throws -> ResultadoCompra {
        guard let derecho = derechoAlComprar(id) else { return .cancelado }
        derechos.append(derecho)
        return .comprado
    }

    func restaurar() async throws { restauraciones += 1 }

    nonisolated func cambios() -> AsyncStream<Void> { flujo }
}

@MainActor
@Suite("Rico Premium")
struct PremiumTests {
    let ahora = Date(timeIntervalSince1970: 1_800_000_000)

    func estado(_ tienda: TiendaFalsa) -> EstadoPremium {
        let fecha = ahora
        return EstadoPremium(tienda: tienda, cache: nil, ahora: { fecha })
    }

    @Test func sinComprasNoEsPremium() async {
        let tienda = TiendaFalsa()
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)
    }

    @Test func premiumConcedidoSinComprar() async {
        let premium = estado(TiendaFalsa())
        premium.conceder(true)
        #expect(premium.esPremium)
        await premium.actualizarDerechos()
        #expect(premium.esPremium)

        premium.conceder(false)
        #expect(!premium.esPremium)
    }

    @Test func compraVerificadaActivaPremium() async throws {
        let tienda = TiendaFalsa()
        let premium = estado(tienda)
        await premium.cargarProductos()
        let anual = try #require(premium.anual)

        let resultado = try await premium.comprar(anual)

        #expect(resultado == .comprado)
        #expect(premium.esPremium)
        #expect(!premium.comprando)
    }

    @Test func compraCanceladaNoActiva() async throws {
        let tienda = TiendaFalsa()
        await tienda.cancelarCompras()
        let premium = estado(tienda)
        await premium.cargarProductos()

        let resultado = try await premium.comprar(try #require(premium.mensual))

        #expect(resultado == .cancelado)
        #expect(!premium.esPremium)
    }

    @Test func suscripcionCaducadaNoEsPremium() async {
        let tienda = TiendaFalsa()
        await tienda.poner(derechos: [
            DerechoPremium(productoID: ProductosPremium.mensual, verificado: true, caducaEn: ahora.addingTimeInterval(-60))
        ])
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)
    }

    @Test func suscripcionRevocadaNoEsPremium() async {
        let tienda = TiendaFalsa()
        await tienda.poner(derechos: [
            DerechoPremium(productoID: ProductosPremium.anual, verificado: true, revocadoEn: ahora.addingTimeInterval(-3600), caducaEn: ahora.addingTimeInterval(86_400))
        ])
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)
    }

    @Test func transaccionSinVerificarNoEsPremium() async {
        let tienda = TiendaFalsa()
        await tienda.poner(derechos: [
            DerechoPremium(productoID: ProductosPremium.anual, verificado: false, caducaEn: ahora.addingTimeInterval(86_400))
        ])
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)
    }

    @Test func productoAjenoNoEsPremium() async {
        let tienda = TiendaFalsa()
        await tienda.poner(derechos: [
            DerechoPremium(productoID: "es.rico.app.otra.cosa", verificado: true, caducaEn: ahora.addingTimeInterval(86_400))
        ])
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)
    }

    @Test func restaurarConCompraVigenteActiva() async throws {
        let tienda = TiendaFalsa()
        let premium = estado(tienda)
        await premium.actualizarDerechos()
        #expect(!premium.esPremium)

        await tienda.poner(derechos: [
            DerechoPremium(productoID: ProductosPremium.anual, verificado: true, caducaEn: ahora.addingTimeInterval(86_400))
        ])
        try await premium.restaurar()

        #expect(premium.esPremium)
        #expect(await tienda.restauraciones == 1)
    }

    @Test func cargaLosPlanesConElAnualPrimeroYSuAhorro() async {
        let premium = estado(TiendaFalsa())
        await premium.cargarProductos()
        #expect(premium.carga == .listo)
        #expect(premium.productos.first?.periodo == .anual)
        // 19,99 € frente a 12 × 2,99 € = 35,88 €: un 44 % menos.
        #expect(premium.ahorroAnual == 44)
        #expect(premium.anual?.diasPrueba == 7)
    }

    @Test func sinConexionNoHayPlanes() async {
        let tienda = TiendaFalsa()
        await tienda.fallarProductos()
        let premium = estado(tienda)
        await premium.cargarProductos()
        #expect(premium.carga == .sinProductos)
        #expect(premium.productos.isEmpty)
    }

    @Test func unaRenovacionFueraDeLaAppSeNota() async throws {
        let tienda = TiendaFalsa()
        let premium = estado(tienda)
        let arranque = Task { await premium.arrancar() }
        defer { arranque.cancel() }

        // Espera a que el arranque haya cargado los planes.
        for _ in 0..<100 where premium.carga != .listo {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!premium.esPremium)

        await tienda.poner(derechos: [
            DerechoPremium(productoID: ProductosPremium.mensual, verificado: true, caducaEn: ahora.addingTimeInterval(86_400))
        ])
        tienda.continuacion.yield()

        for _ in 0..<100 where !premium.esPremium {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(premium.esPremium)
    }
}
