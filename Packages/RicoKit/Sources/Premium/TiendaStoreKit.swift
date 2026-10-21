import Foundation
import StoreKit

/// `TiendaPremium` con StoreKit 2. En Debug usa `Config/Rico.storekit` (ver el esquema en `project.yml`).
public actor TiendaStoreKit: TiendaPremium {
    private var cargados: [String: Product] = [:]

    public init() {}

    public func productos(ids: [String]) async throws -> [ProductoPremium] {
        let productos = try await Product.products(for: ids)
        for producto in productos { cargados[producto.id] = producto }
        var resultado: [ProductoPremium] = []
        for producto in productos {
            guard let periodo = Self.periodo(de: producto) else { continue }
            resultado.append(ProductoPremium(
                id: producto.id,
                periodo: periodo,
                precioTexto: producto.displayPrice,
                precio: producto.price,
                formatoPrecio: producto.priceFormatStyle,
                diasPrueba: await Self.diasPrueba(de: producto)
            ))
        }
        return resultado
    }

    public func derechosActuales() async -> [DerechoPremium] {
        var derechos: [DerechoPremium] = []
        for await resultado in Transaction.currentEntitlements {
            derechos.append(Self.derecho(de: resultado))
        }
        return derechos
    }

    public func comprar(_ id: String) async throws -> ResultadoCompra {
        let producto: Product
        if let cargado = cargados[id] {
            producto = cargado
        } else if let encontrado = try await Product.products(for: [id]).first {
            cargados[id] = encontrado
            producto = encontrado
        } else {
            throw ErrorPremium.productoNoDisponible
        }

        switch try await producto.purchase() {
        case .success(.verified(let transaccion)):
            await transaccion.finish()
            return .comprado
        case .success(.unverified):
            throw ErrorPremium.compraNoVerificada
        case .pending:
            return .pendiente
        case .userCancelled:
            return .cancelado
        @unknown default:
            return .cancelado
        }
    }

    public func restaurar() async throws {
        try await AppStore.sync()
    }

    public nonisolated func cambios() -> AsyncStream<Void> {
        AsyncStream { continuacion in
            let tarea = Task {
                for await resultado in Transaction.updates {
                    if case .verified(let transaccion) = resultado {
                        await transaccion.finish()
                    }
                    continuacion.yield()
                }
                continuacion.finish()
            }
            continuacion.onTermination = { _ in tarea.cancel() }
        }
    }

    // MARK: Conversión

    static func derecho(de resultado: VerificationResult<Transaction>) -> DerechoPremium {
        switch resultado {
        case .verified(let transaccion):
            DerechoPremium(
                productoID: transaccion.productID,
                verificado: true,
                revocadoEn: transaccion.revocationDate,
                caducaEn: transaccion.expirationDate
            )
        case .unverified(let transaccion, _):
            DerechoPremium(
                productoID: transaccion.productID,
                verificado: false,
                revocadoEn: transaccion.revocationDate,
                caducaEn: transaccion.expirationDate
            )
        }
    }

    static func periodo(de producto: Product) -> ProductoPremium.Periodo? {
        guard let periodo = producto.subscription?.subscriptionPeriod else { return nil }
        switch periodo.unit {
        case .year: return .anual
        case .month where periodo.value == 1: return .mensual
        default: return nil
        }
    }

    /// Días de la prueba gratis, solo si este usuario todavía puede usarla.
    static func diasPrueba(de producto: Product) async -> Int? {
        guard let suscripcion = producto.subscription,
              let oferta = suscripcion.introductoryOffer,
              oferta.paymentMode == .freeTrial,
              await suscripcion.isEligibleForIntroOffer
        else { return nil }
        let periodo = oferta.period
        switch periodo.unit {
        case .day: return periodo.value
        case .week: return periodo.value * 7
        case .month: return periodo.value * 30
        case .year: return periodo.value * 365
        @unknown default: return nil
        }
    }
}
