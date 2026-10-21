import Foundation
import SwiftData
import Modelos
import RicoCore

/// Lo que el usuario hace con las visitas que esperan en la bandeja.
@MainActor
public enum AccionesBandeja {
    /// Visitas en borrador, la más reciente primero.
    public static func pendientes(en contexto: ModelContext) throws -> [Visita] {
        let borrador = EstadoVisita.borrador.rawValue
        let descriptor = FetchDescriptor<Visita>(
            predicate: #Predicate { $0.estadoRaw == borrador },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        return try contexto.fetch(descriptor)
    }

    /// «Elegir sitio»: pone el restaurante a la visita y aprende el nombre del pago para la próxima vez.
    @discardableResult
    public static func asignar(_ visita: Visita, lugar: LugarEncontrado, en contexto: ModelContext) throws -> Restaurante {
        let restaurante = try contexto.restaurante(para: lugar)
        try asignar(visita, restaurante: restaurante, en: contexto)
        return restaurante
    }

    /// «Elegir sitio» con un restaurante que ya está en el diario.
    public static func asignar(_ visita: Visita, restaurante: Restaurante, en contexto: ModelContext) throws {
        let anterior = visita.restaurante
        visita.restaurante = restaurante
        if let pago = visita.pago {
            pago.estado = .asignado
            aprender(pago.comercioLimpio, restaurante: restaurante, en: contexto)
        }
        if let anterior, anterior !== restaurante {
            borrarSiHuerfano(anterior, en: contexto)
        }
        try contexto.save()
    }

    /// Tras valorar una visita que venía de un pago: el sitio era el bueno.
    public static func confirmar(_ visita: Visita, en contexto: ModelContext) throws {
        guard let pago = visita.pago, let restaurante = visita.restaurante else { return }
        let yaAprendido = pago.estado == .asignado
        pago.estado = .asignado
        if !yaAprendido {
            aprender(pago.comercioLimpio, restaurante: restaurante, en: contexto)
        }
        try contexto.save()
    }

    /// «No era un restaurante»: borra la visita en borrador y deja el pago descartado.
    public static func descartar(_ visita: Visita, en contexto: ModelContext) throws {
        let restaurante = visita.restaurante
        visita.pago?.estado = .descartado
        visita.pago = nil
        visita.restaurante = nil
        contexto.delete(visita)
        if let restaurante {
            borrarSiHuerfano(restaurante, en: contexto, ignorando: visita)
        }
        try contexto.save()
    }

    // MARK: Ayudas

    static func aprender(_ comercioLimpio: String, restaurante: Restaurante, en contexto: ModelContext) {
        guard !comercioLimpio.isEmpty else { return }
        let descriptor = FetchDescriptor<AliasComercio>(predicate: #Predicate { $0.comercioLimpio == comercioLimpio })
        let existentes = (try? contexto.fetch(descriptor)) ?? []
        if let mismo = existentes.first(where: { $0.restaurante === restaurante }) {
            mismo.vecesConfirmado += 1
        } else {
            // El nombre apuntaba a otro sitio: el usuario lo ha corregido, manda lo nuevo.
            for viejo in existentes { contexto.delete(viejo) }
            let alias = AliasComercio(comercioLimpio: comercioLimpio, restaurante: restaurante)
            contexto.insert(alias)
            alias.restaurante = restaurante
        }
    }

    /// Un restaurante creado solo para proponerlo y que se ha quedado sin visitas ni listas sobra.
    static func borrarSiHuerfano(_ restaurante: Restaurante, en contexto: ModelContext, ignorando: Visita? = nil) {
        let visitas = (restaurante.visitas ?? []).filter { $0 !== ignorando }
        guard visitas.isEmpty, (restaurante.listas ?? []).isEmpty else { return }
        contexto.delete(restaurante)
    }
}
