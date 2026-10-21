import Foundation
import Modelos
import RicoCore

public struct PlatoResumido: Equatable, Sendable {
    public let nombre: String
    public let veces: Int
    public let ultimaValoracion: ValoracionPlato?

    public init(nombre: String, veces: Int, ultimaValoracion: ValoracionPlato?) {
        self.nombre = nombre
        self.veces = veces
        self.ultimaValoracion = ultimaValoracion
    }
}

/// Moneda en la que se suman los importes: la más frecuente entre las visitas con importe.
/// Empate: «EUR» si está entre las empatadas; si no, orden alfabético.
func monedaPrincipal(_ divisas: [String]) -> String? {
    Importe.monedaPrincipal(divisas)
}

/// Cifras de un restaurante, calculadas una vez por pintado.
@MainActor
public struct ResumenRestaurante {
    /// Valoradas, de la más reciente a la más antigua.
    public let visitas: [Visita]
    public let notaMedia: Double?
    public let gastoMedioPorPersona: Importe?
    /// Más pedidos primero; empate: nombre ascendente.
    public let platos: [PlatoResumido]
    public let fotoPortada: Data?

    public init(restaurante: Restaurante) {
        let visitas = (restaurante.visitas ?? [])
            .filter { $0.estado == .valorada }
            .sorted { $0.fecha > $1.fecha }
        self.visitas = visitas

        let notas = visitas.compactMap(\.estrellas)
        notaMedia = notas.isEmpty ? nil : notas.reduce(0, +) / Double(notas.count)

        let importes = visitas.compactMap(\.importePorPersona)
        if let divisa = monedaPrincipal(importes.map(\.divisa)) {
            let enMoneda = importes.filter { $0.divisa == divisa }.map(\.centimos)
            let media = (Double(enMoneda.reduce(0, +)) / Double(enMoneda.count)).rounded()
            gastoMedioPorPersona = Importe(centimos: Int(media), divisa: divisa)
        } else {
            gastoMedioPorPersona = nil
        }

        var grupos: [String: (nombre: String, veces: Int, ultima: ValoracionPlato?)] = [:]
        // `visitas` va de la más reciente a la más antigua: la primera valoración que se ve es la última.
        for visita in visitas {
            for plato in visita.platosOrdenados {
                let clave = plato.nombre.lowercased()
                if var grupo = grupos[clave] {
                    grupo.veces += 1
                    if grupo.ultima == nil { grupo.ultima = plato.valoracion }
                    grupos[clave] = grupo
                } else {
                    grupos[clave] = (plato.nombre, 1, plato.valoracion)
                }
            }
        }
        platos = grupos.values
            .map { PlatoResumido(nombre: $0.nombre, veces: $0.veces, ultimaValoracion: $0.ultima) }
            .sorted { ($0.veces, $1.nombre) > ($1.veces, $0.nombre) }

        fotoPortada = visitas.lazy.compactMap { $0.fotosOrdenadas.first?.miniatura }.first
    }
}

@MainActor
public enum AgrupadorDiario {
    public struct Seccion: Identifiable {
        public let titulo: String
        public let visitas: [Visita]
        public var id: String { titulo }
    }

    /// «Octubre de 2026»; es el título por defecto de las secciones.
    nonisolated public static func tituloMes(_ fecha: Date) -> String {
        FormatoFecha.mes(fecha)
    }

    public static func filtrar(_ visitas: [Visita], busqueda: String) -> [Visita] {
        let texto = busqueda.recortado
        guard !texto.isEmpty else { return visitas }
        return visitas.filter { visita in
            let campos: [String?] = [visita.restaurante?.nombre, visita.restaurante?.ciudad, visita.resena]
                + (visita.platos ?? []).map { Optional($0.nombre) }
            return campos.contains { $0?.localizedStandardContains(texto) == true }
        }
    }

    /// Agrupado por mes, conservando el orden, en un solo recorrido.
    public static func secciones(_ visitas: [Visita], titulo: (Date) -> String = tituloMes) -> [Seccion] {
        var resultado: [Seccion] = []
        var tituloActual: String?
        var acumuladas: [Visita] = []
        for visita in visitas {
            let nuevo = titulo(visita.fecha)
            if let actual = tituloActual, actual != nuevo {
                resultado.append(Seccion(titulo: actual, visitas: acumuladas))
                acumuladas = []
            }
            tituloActual = nuevo
            acumuladas.append(visita)
        }
        if let actual = tituloActual {
            resultado.append(Seccion(titulo: actual, visitas: acumuladas))
        }
        return resultado
    }

    /// Visitas y gasto del mes de `ahora`, en la moneda principal.
    public static func resumenMes(
        _ visitas: [Visita],
        ahora: Date = .now,
        calendario: Calendar = .current
    ) -> (visitas: Int, gasto: Importe) {
        let delMes = visitas.filter { calendario.isDate($0.fecha, equalTo: ahora, toGranularity: .month) }
        let conImporte = delMes.filter { $0.importeCentimos != nil }
        let divisa = monedaPrincipal(conImporte.map(\.divisa)) ?? "EUR"
        let total = conImporte
            .filter { $0.divisa == divisa }
            .compactMap(\.importeCentimos)
            .reduce(0, +)
        return (delMes.count, Importe(centimos: total, divisa: divisa))
    }
}
