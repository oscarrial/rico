import Foundation

/// Importe en céntimos, para no arrastrar errores de coma flotante.
public struct Importe: Hashable, Sendable, Codable, Comparable {
    public var centimos: Int
    public var divisa: String

    public init(centimos: Int, divisa: String = "EUR") {
        self.centimos = centimos
        self.divisa = divisa
    }

    /// Lee lo que escribe el usuario: «48», «48,5», «48,50», «48.50», «1.234,56», «12 €».
    public init?(texto: String, divisa: String = "EUR") {
        var limpio = texto.filter { caracter in
            !caracter.isWhitespace && !"'’€$£".contains(caracter)
        }
        guard !limpio.isEmpty else { return nil }
        guard limpio.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }) else { return nil }

        // El último separador con 1 o 2 cifras detrás es el decimal; el resto son miles.
        if let ultimo = limpio.lastIndex(where: { $0 == "," || $0 == "." }) {
            let decimales = limpio[limpio.index(after: ultimo)...]
            let entera = limpio[..<ultimo].filter { $0 != "," && $0 != "." }
            if decimales.count == 1 || decimales.count == 2 {
                limpio = entera + "." + decimales
            } else {
                limpio = entera + decimales
            }
        }

        guard let valor = Decimal(string: limpio, locale: Locale(identifier: "en_US_POSIX")),
              valor >= 0 else { return nil }
        var centimos = valor * 100
        var redondeado = Decimal()
        NSDecimalRound(&redondeado, &centimos, 0, .plain)
        self.init(centimos: NSDecimalNumber(decimal: redondeado).intValue, divisa: divisa)
    }

    public var decimal: Decimal { Decimal(centimos) / 100 }

    /// Precio por persona: si pagaste todo se divide entre los comensales; si pagaste tu parte, es tu parte.
    public func porPersona(comensales: Int, pagueTodo: Bool) -> Importe {
        guard pagueTodo, comensales > 1 else { return self }
        let dividido = (Double(centimos) / Double(comensales)).rounded()
        return Importe(centimos: Int(dividido), divisa: divisa)
    }

    public static func < (lhs: Importe, rhs: Importe) -> Bool {
        lhs.centimos < rhs.centimos
    }
}
