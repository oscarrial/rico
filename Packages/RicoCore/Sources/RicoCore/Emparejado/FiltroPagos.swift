import Foundation

/// Lo que llega del atajo «Transacción» de Apple Pay.
public struct PagoEntrante: Sendable, Hashable {
    public var comercio: String
    public var importe: Importe
    public var fecha: Date
    public var tarjeta: String?

    public init(comercio: String, importe: Importe, fecha: Date, tarjeta: String? = nil) {
        self.comercio = comercio
        self.importe = importe
        self.fecha = fecha
        self.tarjeta = tarjeta
    }
}

public enum ResultadoFiltro: Sendable, Equatable {
    case aceptar
    case ignorarImporte
    case ignorarTarjeta
    case duplicado
}

/// Filtra pagos antes del emparejado: importe mínimo, tarjetas vigiladas y repetidos
/// (el disparador a veces salta dos veces con el mismo pago).
public struct FiltroPagos: Sendable {
    public var importeMinimo: Importe?
    /// `nil` = todas las tarjetas.
    public var tarjetasVigiladas: Set<String>?
    public var ventanaDuplicado: TimeInterval

    public init(importeMinimo: Importe? = Importe(centimos: 500), tarjetasVigiladas: Set<String>? = nil, ventanaDuplicado: TimeInterval = 5 * 60) {
        self.importeMinimo = importeMinimo
        self.tarjetasVigiladas = tarjetasVigiladas
        self.ventanaDuplicado = ventanaDuplicado
    }

    public func evaluar(_ pago: PagoEntrante, recientes: [PagoEntrante]) -> ResultadoFiltro {
        if let tarjetas = tarjetasVigiladas, let tarjeta = pago.tarjeta, !tarjetas.contains(tarjeta) {
            return .ignorarTarjeta
        }
        if let minimo = importeMinimo, pago.importe < minimo {
            return .ignorarImporte
        }
        let limpio = LimpiadorComercio.limpiar(pago.comercio)
        let repetido = recientes.contains { otro in
            otro.importe == pago.importe
                && abs(otro.fecha.timeIntervalSince(pago.fecha)) < ventanaDuplicado
                && LimpiadorComercio.limpiar(otro.comercio) == limpio
        }
        return repetido ? .duplicado : .aceptar
    }
}
