import Foundation
import SwiftData
import Modelos
import RicoCore

/// Sitios para comer alrededor de un punto. Protocolo para poder probar con datos falsos.
@MainActor
public protocol BuscadorPuntosCercanos {
    func buscar(cerca: Coordenada, radioMetros: Double) async throws -> [LugarEncontrado]
}

/// Convierte una estancia larga en un restaurante en una visita por valorar
/// y avisa con «¿Has comido en …?». Cubre el efectivo, la tarjeta física y cuando invita otro.
@MainActor
public final class ProcesadorEstancias {
    private let contexto: ModelContext
    private let buscador: any BuscadorPuntosCercanos
    private let notificador: (any Notificador)?
    private let evaluador: EvaluadorEstancia
    private let historial: HistorialEstancias

    public init(
        contexto: ModelContext,
        buscador: any BuscadorPuntosCercanos,
        notificador: (any Notificador)? = nil,
        evaluador: EvaluadorEstancia = EvaluadorEstancia(),
        historial: HistorialEstancias = HistorialEstancias()
    ) {
        self.contexto = contexto
        self.buscador = buscador
        self.notificador = notificador
        self.evaluador = evaluador
        self.historial = historial
    }

    /// - Returns: el id de la visita creada, o `nil` si no parecía una comida.
    @discardableResult
    public func procesar(_ estancia: Estancia, silenciados: Set<String> = []) async -> UUID? {
        // Donde se duerme no se come: se apunta para no preguntar por los bares de al lado.
        if evaluador.esNoche(estancia) {
            historial.anotarNoche(LugarDormido(latitud: estancia.latitud, longitud: estancia.longitud, fecha: estancia.salida))
            Registro.captura.info("Estancia de noche: se recuerda el sitio")
            return nil
        }
        let noches = historial.noches(ahora: estancia.salida)
        let silenciados = silenciados.union(historial.silenciados)

        // Lo barato primero: si dura poco, no es hora de comer o ya hay una visita, no se busca nada.
        let previa = evaluador.decidir(estancia, candidatos: [], registradas: registradas(cerca: estancia), noches: noches)
        switch previa {
        case .ignorar(.sinCandidatos):
            break
        case let .ignorar(motivo):
            Registro.captura.info("Estancia ignorada: \(String(describing: motivo), privacy: .public)")
            return nil
        case .preguntar:
            break
        }

        let lugares: [LugarEncontrado]
        do {
            lugares = try await buscador.buscar(
                cerca: Coordenada(latitud: estancia.latitud, longitud: estancia.longitud),
                radioMetros: evaluador.radioMetros * 2
            )
        } catch {
            Registro.captura.notice("Falló la búsqueda alrededor de la estancia: \(String(describing: error), privacy: .public)")
            return nil
        }

        let porID = Dictionary(lugares.map { ($0.id, $0) }, uniquingKeysWith: { primero, _ in primero })
        let candidatos = lugares.map {
            CandidatoEstancia(id: $0.id, nombre: $0.nombre, categoria: $0.categoria, latitud: $0.latitud, longitud: $0.longitud)
        }
        guard case let .preguntar(id, distancia) = evaluador.decidir(
            estancia,
            candidatos: candidatos,
            registradas: registradas(cerca: estancia),
            silenciados: silenciados,
            noches: noches
        ), let lugar = porID[id] else {
            Registro.captura.info("Estancia sin un restaurante claro cerca")
            return nil
        }

        do {
            let restaurante = try contexto.restaurante(para: lugar)
            let visita = Visita(fecha: estancia.llegada, origen: .ubicacion)
            visita.estado = .borrador
            contexto.insert(visita)
            visita.restaurante = restaurante
            try contexto.save()
            Registro.captura.info("Estancia guardada a \(Int(distancia), privacy: .public) m del sitio")
            await notificador?.programarEstancia(visitaID: visita.id, sitio: restaurante.nombre, desde: estancia.llegada, hasta: estancia.salida)
            return visita.id
        } catch {
            contexto.rollback()
            Registro.captura.error("No se pudo guardar la estancia: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Fechas de las visitas de ese día, para no preguntar por una comida que ya está apuntada.
    private func registradas(cerca estancia: Estancia) -> [Date] {
        let fin = estancia.salida == .distantFuture ? estancia.llegada : estancia.salida
        let desde = estancia.llegada.addingTimeInterval(-6 * 3600)
        let hasta = fin.addingTimeInterval(6 * 3600)
        let descartada = EstadoVisita.descartada.rawValue
        let descriptor = FetchDescriptor<Visita>(predicate: #Predicate {
            $0.fecha >= desde && $0.fecha <= hasta && $0.estadoRaw != descartada
        })
        return ((try? contexto.fetch(descriptor)) ?? []).map(\.fecha)
    }
}
