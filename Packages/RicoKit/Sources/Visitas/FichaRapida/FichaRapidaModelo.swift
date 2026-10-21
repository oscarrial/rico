import Foundation
import Observation
import SwiftData
import Modelos
import RicoCore

public struct BorradorPlato: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var nombre: String
    public var valoracion: ValoracionPlato?

    public init(id: UUID = UUID(), nombre: String = "", valoracion: ValoracionPlato? = nil) {
        self.id = id
        self.nombre = nombre
        self.valoracion = valoracion
    }
}

public struct BorradorFoto: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let miniatura: Data
    /// `nil` en fotos ya guardadas: no hace falta volver a cargarlas.
    public let datos: Data?
    public let fecha: Date
    public let identificadorCarrete: String?

    public init(id: UUID = UUID(), miniatura: Data, datos: Data?, fecha: Date, identificadorCarrete: String? = nil) {
        self.id = id
        self.miniatura = miniatura
        self.datos = datos
        self.fecha = fecha
        self.identificadorCarrete = identificadorCarrete
    }
}

public enum ErrorFicha: Error, Equatable {
    case sinNota
}

/// Estado de la ficha rápida de valoración. Trabaja sobre un borrador y solo toca
/// SwiftData al guardar, así cancelar no deja nada a medias.
@MainActor
@Observable
public final class FichaRapidaModelo {
    enum Destino {
        case nueva(LugarEncontrado)
        case manual(RestauranteManual)
        case restaurante(Restaurante)
        case existente(Visita)
    }

    let destino: Destino

    public private(set) var nombreRestaurante: String
    public private(set) var lugarTexto: String?
    public private(set) var latitud: Double?
    public private(set) var longitud: Double?

    public var fecha: Date
    public var estrellas: Double = 0
    public var importeTexto: String = ""
    public var comensales: Int = 1
    public var pagueTodo: Bool = true
    public var volveria: Volveria?
    public var platos: [BorradorPlato] = []
    public var fotos: [BorradorFoto] = []
    private var fotosQuitadas: Set<UUID> = []
    private let divisa: String
    public var notas: String = ""

    /// Visita nueva en un sitio encontrado en el buscador.
    public init(lugar: LugarEncontrado, fecha: Date = .now) {
        destino = .nueva(lugar)
        nombreRestaurante = lugar.nombre
        lugarTexto = [lugar.direccion, lugar.ciudad].compactMap { $0 }.joined(separator: ", ").nilSiVacio
        latitud = lugar.latitud
        longitud = lugar.longitud
        divisa = "EUR"
        self.fecha = fecha
    }

    /// Visita nueva en un restaurante escrito a mano (no aparecía en el buscador).
    public init(manual datos: RestauranteManual, fecha: Date = .now) {
        destino = .manual(datos)
        nombreRestaurante = datos.nombre.recortado
        lugarTexto = [datos.direccion, datos.ciudad].compactMap { $0?.nilSiVacio }.joined(separator: ", ").nilSiVacio
        latitud = nil
        longitud = nil
        divisa = "EUR"
        self.fecha = fecha
    }

    /// Visita nueva en un restaurante que ya está en el diario.
    public init(restaurante: Restaurante, fecha: Date = .now) {
        destino = .restaurante(restaurante)
        nombreRestaurante = restaurante.nombre
        lugarTexto = [restaurante.direccion, restaurante.ciudad].compactMap { $0 }.joined(separator: ", ").nilSiVacio
        latitud = restaurante.latitud
        longitud = restaurante.longitud
        divisa = "EUR"
        self.fecha = fecha
    }

    /// Editar o valorar una visita que ya existe (también los borradores detectados).
    public init(visita: Visita) {
        destino = .existente(visita)
        let restaurante = visita.restaurante
        nombreRestaurante = restaurante?.nombre ?? ""
        lugarTexto = [restaurante?.direccion, restaurante?.ciudad].compactMap { $0 }.joined(separator: ", ").nilSiVacio
        latitud = restaurante?.latitud
        longitud = restaurante?.longitud
        divisa = visita.divisa
        fecha = visita.fecha
        estrellas = visita.estrellas ?? 0
        importeTexto = visita.importe?.textoEditable ?? ""
        comensales = visita.comensales
        pagueTodo = visita.pagueTodo
        volveria = visita.volveria
        notas = visita.resena ?? ""
        platos = visita.platosOrdenados.map { BorradorPlato(id: $0.id, nombre: $0.nombre, valoracion: $0.valoracion) }
        fotos = visita.fotosOrdenadas.compactMap { foto in
            guard let miniatura = foto.miniatura else { return nil }
            return BorradorFoto(id: foto.id, miniatura: miniatura, datos: nil, fecha: foto.fecha, identificadorCarrete: foto.identificadorCarrete)
        }
    }

    /// El importe viene del pago y no se puede cambiar la fecha si la creó Apple Pay.
    public var esManual: Bool {
        if case let .existente(visita) = destino { return visita.origen == .manual }
        return true
    }

    public var puedeGuardar: Bool { estrellas > 0 }
    public var importe: Importe? { Importe(texto: importeTexto, divisa: divisa) }
    public var importePorPersona: Importe? { importe?.porPersona(comensales: comensales, pagueTodo: pagueTodo) }
    public var textoPorPersona: String? { importePorPersona?.textoMoneda }

    public var fotosRestantes: Int { max(0, LimitesGratis.fotosPorVisita - fotos.count) }

    public func anadirPlato() {
        platos.append(BorradorPlato())
    }

    public func quitarPlato(_ id: UUID) {
        platos.removeAll { $0.id == id }
    }

    /// Añade una foto si quedan huecos y no estaba ya.
    @discardableResult
    public func anadirFoto(_ foto: BorradorFoto) -> Bool {
        guard fotosRestantes > 0 else { return false }
        if let carrete = foto.identificadorCarrete, fotos.contains(where: { $0.identificadorCarrete == carrete }) {
            return false
        }
        fotos.append(foto)
        return true
    }

    public func quitarFoto(_ id: UUID) {
        fotos.removeAll { $0.id == id }
        fotosQuitadas.insert(id)
    }

    public func contiene(fotoDelCarrete id: String) -> Bool {
        fotos.contains { $0.identificadorCarrete == id }
    }

    @discardableResult
    public func guardar(en contexto: ModelContext) throws -> Visita {
        guard puedeGuardar else { throw ErrorFicha.sinNota }

        do {
            let visita: Visita
            switch destino {
            case let .nueva(lugar):
                let restaurante = try contexto.restaurante(para: lugar)
                visita = Visita(fecha: fecha, origen: .manual)
                contexto.insert(visita)
                visita.restaurante = restaurante
            case let .manual(datos):
                let restaurante = try contexto.restaurante(manual: datos)
                visita = Visita(fecha: fecha, origen: .manual)
                contexto.insert(visita)
                visita.restaurante = restaurante
            case let .restaurante(restaurante):
                visita = Visita(fecha: fecha, origen: .manual)
                contexto.insert(visita)
                visita.restaurante = restaurante
            case let .existente(existente):
                visita = existente
                if esManual { visita.fecha = fecha }
            }

            visita.estrellas = Estrellas.normalizar(estrellas)
            visita.importe = importe
            visita.comensales = max(1, comensales)
            visita.pagueTodo = pagueTodo
            visita.volveria = volveria
            visita.resena = notas.nilSiVacio

            guardarPlatos(en: visita, contexto: contexto)
            guardarFotos(en: visita, contexto: contexto)

            visita.estado = .valorada
            try contexto.save()
            return visita
        } catch {
            contexto.rollback()
            throw error
        }
    }

    private func guardarPlatos(en visita: Visita, contexto: ModelContext) {
        let anteriores = visita.platos ?? []
        let existentes = Dictionary(anteriores.map { ($0.id, $0) }, uniquingKeysWith: { primero, _ in primero })
        var conservados: Set<UUID> = []
        for (orden, borrador) in platos.enumerated() {
            guard let nombre = borrador.nombre.nilSiVacio else { continue }
            if let plato = existentes[borrador.id] {
                plato.nombre = nombre
                plato.valoracion = borrador.valoracion
                plato.orden = orden
            } else {
                let plato = Plato(nombre: nombre, valoracion: borrador.valoracion, orden: orden)
                plato.id = borrador.id
                contexto.insert(plato)
                plato.visita = visita
            }
            conservados.insert(borrador.id)
        }
        for plato in anteriores where !conservados.contains(plato.id) {
            contexto.delete(plato)
        }
    }

    private func guardarFotos(en visita: Visita, contexto: ModelContext) {
        let existentes = visita.fotos ?? []
        for foto in existentes where fotosQuitadas.contains(foto.id) {
            contexto.delete(foto)
        }
        for (orden, borrador) in fotos.enumerated() {
            if let existente = existentes.first(where: { $0.id == borrador.id }) {
                existente.orden = orden
            } else if let datos = borrador.datos {
                let foto = Foto(datos: datos, miniatura: borrador.miniatura, fecha: borrador.fecha, orden: orden)
                foto.id = borrador.id
                foto.identificadorCarrete = borrador.identificadorCarrete
                contexto.insert(foto)
                foto.visita = visita
            }
        }
    }
}
