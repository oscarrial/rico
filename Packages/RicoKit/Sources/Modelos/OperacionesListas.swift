import Foundation
import SwiftData
import RicoCore

/// Por qué no se ha podido crear o cambiar una lista.
public enum ErrorListas: Error, Equatable, Sendable {
    /// Ya hay `LimitesGratis.listasPropias` listas propias y la cuenta no es Premium.
    case limiteGratis
    /// El nombre está vacío.
    case sinNombre
    /// «Quiero probar» no se puede borrar ni renombrar.
    case listaFija
}

public extension Lista {
    /// Nombre con el que se guarda «Quiero probar». Las vistas lo muestran traducido según `tipo`.
    static let nombreQuieroProbar = "Quiero probar"

    /// Si el restaurante ya está en la lista.
    func contiene(_ restaurante: Restaurante) -> Bool {
        (restaurantes ?? []).contains { $0.id == restaurante.id }
    }
}

/// Operaciones de listas compartidas por la pestaña Listas, la ficha del restaurante y el mapa.
public extension ModelContext {
    /// «Quiero probar»: existe siempre. Se crea la primera vez que se pide.
    func listaQuieroProbar() throws -> Lista {
        let tipo = TipoLista.quieroProbar.rawValue
        var descriptor = FetchDescriptor<Lista>(
            predicate: #Predicate { $0.tipoRaw == tipo },
            sortBy: [SortDescriptor(\.fechaCreacion)]
        )
        descriptor.fetchLimit = 1
        if let existente = try fetch(descriptor).first {
            return existente
        }
        let nueva = Lista(nombre: Lista.nombreQuieroProbar, tipo: .quieroProbar)
        insert(nueva)
        try save()
        return nueva
    }

    /// Listas propias, por `orden`.
    func listasPropias() throws -> [Lista] {
        let tipo = TipoLista.propia.rawValue
        return try fetch(FetchDescriptor<Lista>(
            predicate: #Predicate { $0.tipoRaw == tipo },
            sortBy: [SortDescriptor(\.orden), SortDescriptor(\.fechaCreacion)]
        ))
    }

    /// Si se puede crear otra lista propia con el plan actual.
    func puedeCrearListaPropia(esPremium: Bool) throws -> Bool {
        if esPremium { return true }
        let tipo = TipoLista.propia.rawValue
        let cuantas = try fetchCount(FetchDescriptor<Lista>(predicate: #Predicate { $0.tipoRaw == tipo }))
        return cuantas < LimitesGratis.listasPropias
    }

    /// Crea una lista propia al final, respetando el límite del plan gratis.
    @discardableResult
    func crearLista(nombre: String, emoji: String? = nil, esPremium: Bool) throws -> Lista {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { throw ErrorListas.sinNombre }
        guard try puedeCrearListaPropia(esPremium: esPremium) else { throw ErrorListas.limiteGratis }
        let propias = try listasPropias()
        let lista = Lista(nombre: limpio, tipo: .propia)
        lista.emoji = emoji
        lista.orden = (propias.map(\.orden).max() ?? -1) + 1
        insert(lista)
        try save()
        return lista
    }

    /// Cambia nombre y emoji de una lista propia.
    func renombrar(_ lista: Lista, nombre: String, emoji: String?) throws {
        guard lista.tipo == .propia else { throw ErrorListas.listaFija }
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { throw ErrorListas.sinNombre }
        lista.nombre = limpio
        lista.emoji = emoji
        try save()
    }

    /// Borra una lista propia. Los restaurantes se quedan en el diario.
    func borrar(_ lista: Lista) throws {
        guard lista.tipo == .propia else { throw ErrorListas.listaFija }
        lista.restaurantes = []
        delete(lista)
        try save()
    }

    /// Añade el restaurante a la lista si no estaba ya.
    func anadir(_ restaurante: Restaurante, a lista: Lista) throws {
        guard !lista.contiene(restaurante) else { return }
        var actuales = lista.restaurantes ?? []
        actuales.append(restaurante)
        lista.restaurantes = actuales
        try save()
    }

    /// Quita el restaurante de la lista (no lo borra).
    func quitar(_ restaurante: Restaurante, de lista: Lista) throws {
        lista.restaurantes = (lista.restaurantes ?? []).filter { $0.id != restaurante.id }
        try save()
    }

    /// Guarda el nuevo orden de las listas propias.
    func ordenar(_ listas: [Lista]) throws {
        for (posicion, lista) in listas.enumerated() where lista.orden != posicion {
            lista.orden = posicion
        }
        try save()
    }
}
