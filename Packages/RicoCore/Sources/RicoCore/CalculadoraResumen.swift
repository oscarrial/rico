import Foundation

public extension Importe {
    /// Moneda en la que se suman los importes: la más frecuente.
    /// Empate: «EUR» si está entre las empatadas; si no, orden alfabético.
    static func monedaPrincipal(_ divisas: [String]) -> String? {
        var cuentas: [String: Int] = [:]
        for divisa in divisas { cuentas[divisa, default: 0] += 1 }
        guard let maximo = cuentas.values.max() else { return nil }
        let empatadas = cuentas.filter { $0.value == maximo }.map(\.key)
        if empatadas.contains("EUR") { return "EUR" }
        return empatadas.sorted().first
    }
}

/// Lo que el resumen necesita de una visita, sin SwiftData, para poder probarlo en cualquier sitio.
public struct VisitaResumible: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var fecha: Date
    /// Solo cuentan las valoradas: los borradores y las descartadas se ignoran.
    public var valorada: Bool
    public var estrellas: Double?
    /// Lo que pagaste (la cuenta entera o tu parte).
    public var importe: Importe?
    public var comensales: Int
    public var pagueTodo: Bool
    public var restauranteID: UUID?
    public var restaurante: String
    public var ciudad: String?
    public var cocina: String?
    /// Platos marcados con «me encantó», en el orden de la visita.
    public var platosEncanto: [String]

    public init(
        id: UUID = UUID(),
        fecha: Date,
        valorada: Bool = true,
        estrellas: Double? = nil,
        importe: Importe? = nil,
        comensales: Int = 1,
        pagueTodo: Bool = true,
        restauranteID: UUID? = nil,
        restaurante: String = "",
        ciudad: String? = nil,
        cocina: String? = nil,
        platosEncanto: [String] = []
    ) {
        self.id = id
        self.fecha = fecha
        self.valorada = valorada
        self.estrellas = estrellas
        self.importe = importe
        self.comensales = comensales
        self.pagueTodo = pagueTodo
        self.restauranteID = restauranteID
        self.restaurante = restaurante
        self.ciudad = ciudad
        self.cocina = cocina
        self.platosEncanto = platosEncanto
    }

    public var importePorPersona: Importe? {
        importe?.porPersona(comensales: comensales, pagueTodo: pagueTodo)
    }

    /// Identifica el sitio aunque se haya escrito a mano sin id.
    var claveSitio: String {
        restauranteID?.uuidString ?? restaurante.lowercased()
    }
}

/// Cifras de un mes.
public struct CifrasMes: Sendable, Equatable {
    public var visitas: Int
    /// Suma de lo pagado en la moneda principal del mes; `nil` si ninguna visita tiene importe.
    public var gasto: Importe?
    public var gastoMedioPorPersona: Importe?
    public var notaMedia: Double?
    /// Sitios a los que fuiste por primera vez este mes.
    public var sitiosNuevos: Int
    /// Sitios donde ya habías estado antes de este mes.
    public var sitiosRepetidos: Int

    public init(
        visitas: Int = 0,
        gasto: Importe? = nil,
        gastoMedioPorPersona: Importe? = nil,
        notaMedia: Double? = nil,
        sitiosNuevos: Int = 0,
        sitiosRepetidos: Int = 0
    ) {
        self.visitas = visitas
        self.gasto = gasto
        self.gastoMedioPorPersona = gastoMedioPorPersona
        self.notaMedia = notaMedia
        self.sitiosNuevos = sitiosNuevos
        self.sitiosRepetidos = sitiosRepetidos
    }
}

/// Cómo va el mes frente al anterior. Cada valor es `nil` cuando la comparación no tiene sentido.
public struct Comparacion: Sendable, Equatable {
    /// Variación del gasto (0,12 = un 12 % más). Solo si los dos meses tienen gasto en la misma moneda.
    public var gasto: Double?
    /// Visitas de más (positivo) o de menos (negativo). Solo si el mes anterior tuvo visitas.
    public var visitas: Int?
}

/// Gasto de una semana del mes (de lunes a domingo, recortada a los días del mes).
public struct GastoSemana: Sendable, Equatable, Identifiable {
    /// Primer día de la semana dentro del mes, a medianoche.
    public var inicio: Date
    /// Medianoche del día siguiente al último día.
    public var fin: Date
    public var diaInicio: Int
    public var diaFin: Int
    public var gasto: Importe
    public var visitas: Int

    public var id: Date { inicio }
}

/// Un sitio del top del mes.
public struct SitioDestacado: Sendable, Equatable, Identifiable {
    public var restauranteID: UUID?
    public var nombre: String
    public var ciudad: String?
    public var notaMedia: Double
    public var visitas: Int

    public var id: String { restauranteID?.uuidString ?? nombre.lowercased() }
}

/// Un plato que te encantó.
public struct PlatoDestacado: Sendable, Equatable, Identifiable {
    public var nombre: String
    public var restaurante: String
    public var restauranteID: UUID?
    public var fecha: Date

    public var id: String { "\(restauranteID?.uuidString ?? restaurante.lowercased())|\(nombre.lowercased())" }
}

/// Todo lo que enseña la pestaña Resumen para un mes.
public struct ResumenMes: Sendable, Equatable {
    /// Primer instante del mes.
    public var mes: Date
    public var cifras: CifrasMes
    public var anterior: CifrasMes
    public var comparacion: Comparacion
    public var semanas: [GastoSemana]
    /// Hasta 3 sitios, de mejor a peor nota.
    public var mejoresSitios: [SitioDestacado]
    /// Del más reciente al más antiguo, sin repetir plato en el mismo sitio.
    public var platosEncanto: [PlatoDestacado]

    public var estaVacio: Bool { cifras.visitas == 0 }
    /// Moneda del gráfico de semanas.
    public var divisa: String { cifras.gasto?.divisa ?? "EUR" }
}

public struct GastoMensual: Sendable, Equatable, Identifiable {
    public var mes: Date
    public var gasto: Importe
    public var visitas: Int
    public var id: Date { mes }
}

public struct GastoEtiquetado: Sendable, Equatable, Identifiable {
    public var nombre: String
    public var gasto: Importe
    public var visitas: Int
    public var id: String { nombre }
}

public struct CiudadVisitada: Sendable, Equatable, Identifiable {
    public var nombre: String
    public var visitas: Int
    public var id: String { nombre }
}

/// «Tu año en Rico»: los 12 meses que acaban en el mes elegido.
public struct ResumenAnual: Sendable, Equatable {
    /// 12 meses, del más antiguo al más reciente.
    public var meses: [GastoMensual]
    /// Hasta 5 tipos de cocina, de más a menos gasto.
    public var porCocina: [GastoEtiquetado]
    /// Hasta 5 ciudades, de más a menos visitas.
    public var ciudades: [CiudadVisitada]
    public var divisa: String
    public var visitas: Int
    public var gasto: Importe

    public var estaVacio: Bool { visitas == 0 }
}

/// Cálculos de la pestaña Resumen. Sin estado y sin frameworks de Apple.
public enum CalculadoraResumen {
    public static let maximoTop = 3
    public static let maximoAnual = 5

    /// Calendario gregoriano con la semana empezando en lunes, como en España.
    public static func calendarioEspanol(zonaHoraria: TimeZone = .current) -> Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zonaHoraria
        calendario.firstWeekday = 2
        calendario.minimumDaysInFirstWeek = 4
        return calendario
    }

    // MARK: Meses

    public static func inicioMes(_ fecha: Date, calendario: Calendar) -> Date {
        calendario.dateInterval(of: .month, for: fecha)?.start ?? fecha
    }

    /// El mes que está `meses` antes (negativo) o después (positivo).
    public static func mes(_ mes: Date, desplazado meses: Int, calendario: Calendar) -> Date {
        let inicio = inicioMes(mes, calendario: calendario)
        return calendario.date(byAdding: .month, value: meses, to: inicio) ?? inicio
    }

    /// No se puede pasar del mes actual.
    public static func puedeAvanzar(desde mes: Date, ahora: Date, calendario: Calendar) -> Bool {
        inicioMes(mes, calendario: calendario) < inicioMes(ahora, calendario: calendario)
    }

    /// El último mes anterior a `mes` con alguna visita valorada.
    public static func ultimoMesConVisitas(_ visitas: [VisitaResumible], antesDe mes: Date, calendario: Calendar) -> Date? {
        let inicio = inicioMes(mes, calendario: calendario)
        return visitas
            .filter { $0.valorada && $0.fecha < inicio }
            .map(\.fecha)
            .max()
            .map { inicioMes($0, calendario: calendario) }
    }

    /// Semanas del mes, de lunes a domingo (según `calendario.firstWeekday`), recortadas al mes.
    public static func semanas(de mes: Date, calendario: Calendar) -> [DateInterval] {
        guard let intervalo = calendario.dateInterval(of: .month, for: mes) else { return [] }
        var resultado: [DateInterval] = []
        var inicioSemana = intervalo.start
        var dia = intervalo.start
        while dia < intervalo.end {
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: dia) else { break }
            let cierra = siguiente >= intervalo.end
                || calendario.component(.weekday, from: siguiente) == calendario.firstWeekday
            if cierra {
                let fin = min(siguiente, intervalo.end)
                resultado.append(DateInterval(start: inicioSemana, end: fin))
                inicioSemana = fin
            }
            dia = siguiente
        }
        return resultado
    }

    // MARK: Resumen del mes

    public static func resumen(de visitas: [VisitaResumible], mes: Date, calendario: Calendar) -> ResumenMes {
        let valoradas = visitas.filter(\.valorada)
        let inicio = inicioMes(mes, calendario: calendario)
        let inicioAnterior = self.mes(inicio, desplazado: -1, calendario: calendario)
        let fin = self.mes(inicio, desplazado: 1, calendario: calendario)

        let delMes = valoradas.filter { $0.fecha >= inicio && $0.fecha < fin }
        let delAnterior = valoradas.filter { $0.fecha >= inicioAnterior && $0.fecha < inicio }

        let actual = Self.cifras(delMes, previas: valoradas.filter { $0.fecha < inicio })
        let anterior = Self.cifras(delAnterior, previas: valoradas.filter { $0.fecha < inicioAnterior })

        let divisa = actual.gasto?.divisa ?? "EUR"
        let gastoSemanas = Self.semanas(de: inicio, calendario: calendario).map { semana in
            let enSemana = delMes.filter { $0.fecha >= semana.start && $0.fecha < semana.end }
            return GastoSemana(
                inicio: semana.start,
                fin: semana.end,
                diaInicio: calendario.component(.day, from: semana.start),
                diaFin: calendario.component(.day, from: semana.end.addingTimeInterval(-1)),
                gasto: suma(enSemana.compactMap(\.importe), divisa: divisa),
                visitas: enSemana.count
            )
        }

        return ResumenMes(
            mes: inicio,
            cifras: actual,
            anterior: anterior,
            comparacion: comparar(actual, con: anterior),
            semanas: gastoSemanas,
            mejoresSitios: mejoresSitios(delMes),
            platosEncanto: platosEncanto(delMes)
        )
    }

    /// Cifras de un grupo de visitas valoradas. `previas` son las de antes, para saber qué sitios repites.
    static func cifras(_ visitas: [VisitaResumible], previas: [VisitaResumible]) -> CifrasMes {
        let importes = visitas.compactMap(\.importe)
        let gasto = monedaPrincipalDe(importes).map { suma(importes, divisa: $0) }

        let porPersona = visitas.compactMap(\.importePorPersona)
        var gastoMedio: Importe?
        if let divisa = monedaPrincipalDe(porPersona) {
            let enMoneda = porPersona.filter { $0.divisa == divisa }.map(\.centimos)
            let media = (Double(enMoneda.reduce(0, +)) / Double(enMoneda.count)).rounded()
            gastoMedio = Importe(centimos: Int(media), divisa: divisa)
        }

        let notas = visitas.compactMap(\.estrellas)
        let notaMedia = notas.isEmpty ? nil : notas.reduce(0, +) / Double(notas.count)

        let conocidos = Set(previas.map(\.claveSitio))
        let sitios = Set(visitas.map(\.claveSitio))
        let repetidos = sitios.filter { conocidos.contains($0) }.count

        return CifrasMes(
            visitas: visitas.count,
            gasto: gasto,
            gastoMedioPorPersona: gastoMedio,
            notaMedia: notaMedia,
            sitiosNuevos: sitios.count - repetidos,
            sitiosRepetidos: repetidos
        )
    }

    static func comparar(_ actual: CifrasMes, con anterior: CifrasMes) -> Comparacion {
        var gasto: Double?
        if let ahora = actual.gasto, let antes = anterior.gasto,
           ahora.divisa == antes.divisa, antes.centimos > 0 {
            gasto = Double(ahora.centimos - antes.centimos) / Double(antes.centimos)
        }
        let visitas = anterior.visitas > 0 && actual.visitas > 0 ? actual.visitas - anterior.visitas : nil
        return Comparacion(gasto: gasto, visitas: visitas)
    }

    /// Los mejores sitios por nota media; empate: más visitas y luego nombre.
    static func mejoresSitios(_ visitas: [VisitaResumible]) -> [SitioDestacado] {
        var grupos: [String: (primera: VisitaResumible, notas: [Double], visitas: Int)] = [:]
        for visita in visitas {
            var grupo = grupos[visita.claveSitio] ?? (primera: visita, notas: [], visitas: 0)
            grupo.visitas += 1
            if let estrellas = visita.estrellas { grupo.notas.append(estrellas) }
            grupos[visita.claveSitio] = grupo
        }
        return grupos.values
            .compactMap { grupo -> SitioDestacado? in
                guard !grupo.notas.isEmpty else { return nil }
                return SitioDestacado(
                    restauranteID: grupo.primera.restauranteID,
                    nombre: grupo.primera.restaurante,
                    ciudad: grupo.primera.ciudad,
                    notaMedia: grupo.notas.reduce(0, +) / Double(grupo.notas.count),
                    visitas: grupo.visitas
                )
            }
            .sorted { a, b in
                if a.notaMedia != b.notaMedia { return a.notaMedia > b.notaMedia }
                if a.visitas != b.visitas { return a.visitas > b.visitas }
                return a.nombre.lowercased() < b.nombre.lowercased()
            }
            .prefix(maximoTop)
            .map { $0 }
    }

    static func platosEncanto(_ visitas: [VisitaResumible]) -> [PlatoDestacado] {
        var vistos: Set<String> = []
        var resultado: [PlatoDestacado] = []
        for visita in visitas.sorted(by: { $0.fecha > $1.fecha }) {
            for nombre in visita.platosEncanto {
                let plato = PlatoDestacado(
                    nombre: nombre,
                    restaurante: visita.restaurante,
                    restauranteID: visita.restauranteID,
                    fecha: visita.fecha
                )
                if vistos.insert(plato.id).inserted { resultado.append(plato) }
            }
        }
        return resultado
    }

    // MARK: Tu año

    /// Los 12 meses que acaban en `mes` (incluido).
    public static func resumenAnual(de visitas: [VisitaResumible], hasta mes: Date, calendario: Calendar) -> ResumenAnual {
        let ultimo = inicioMes(mes, calendario: calendario)
        let inicio = self.mes(ultimo, desplazado: -11, calendario: calendario)
        let fin = self.mes(ultimo, desplazado: 1, calendario: calendario)
        let delAno = visitas.filter { $0.valorada && $0.fecha >= inicio && $0.fecha < fin }
        let divisa = monedaPrincipalDe(delAno.compactMap(\.importe)) ?? "EUR"

        let meses = (0..<12).map { indice -> GastoMensual in
            let desde = self.mes(inicio, desplazado: indice, calendario: calendario)
            let hasta = self.mes(inicio, desplazado: indice + 1, calendario: calendario)
            let enMes = delAno.filter { $0.fecha >= desde && $0.fecha < hasta }
            return GastoMensual(mes: desde, gasto: suma(enMes.compactMap(\.importe), divisa: divisa), visitas: enMes.count)
        }

        var cocinas: [String: (nombre: String, centimos: Int, visitas: Int)] = [:]
        var ciudades: [String: (nombre: String, visitas: Int)] = [:]
        for visita in delAno {
            if let cocina = limpio(visita.cocina) {
                var grupo = cocinas[cocina.lowercased()] ?? (nombre: cocina, centimos: 0, visitas: 0)
                grupo.visitas += 1
                if let importe = visita.importe, importe.divisa == divisa { grupo.centimos += importe.centimos }
                cocinas[cocina.lowercased()] = grupo
            }
            if let ciudad = limpio(visita.ciudad) {
                var grupo = ciudades[ciudad.lowercased()] ?? (nombre: ciudad, visitas: 0)
                grupo.visitas += 1
                ciudades[ciudad.lowercased()] = grupo
            }
        }

        let porCocina = cocinas.values
            .sorted { a, b in
                if a.centimos != b.centimos { return a.centimos > b.centimos }
                if a.visitas != b.visitas { return a.visitas > b.visitas }
                return a.nombre.lowercased() < b.nombre.lowercased()
            }
            .prefix(maximoAnual)
            .map { GastoEtiquetado(nombre: $0.nombre, gasto: Importe(centimos: $0.centimos, divisa: divisa), visitas: $0.visitas) }

        let topCiudades = ciudades.values
            .sorted { a, b in
                if a.visitas != b.visitas { return a.visitas > b.visitas }
                return a.nombre.lowercased() < b.nombre.lowercased()
            }
            .prefix(maximoAnual)
            .map { CiudadVisitada(nombre: $0.nombre, visitas: $0.visitas) }

        return ResumenAnual(
            meses: meses,
            porCocina: porCocina,
            ciudades: topCiudades,
            divisa: divisa,
            visitas: delAno.count,
            gasto: suma(delAno.compactMap(\.importe), divisa: divisa)
        )
    }

    // MARK: Ayudas

    private static func monedaPrincipalDe(_ importes: [Importe]) -> String? {
        Importe.monedaPrincipal(importes.map(\.divisa))
    }

    /// Suma solo los importes en `divisa`: las otras monedas no se mezclan.
    private static func suma(_ importes: [Importe], divisa: String) -> Importe {
        Importe(centimos: importes.filter { $0.divisa == divisa }.map(\.centimos).reduce(0, +), divisa: divisa)
    }

    private static func limpio(_ texto: String?) -> String? {
        guard let texto = texto?.trimmingCharacters(in: .whitespacesAndNewlines), !texto.isEmpty else { return nil }
        return texto
    }
}
