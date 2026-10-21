import Foundation
import Supabase

/// Sincronización con Supabase (PostgREST y Storage), con el mismo cliente que la cuenta.
public final class ServicioSincronizacionSupabase: ServicioSincronizacion {
    public static let bucket = "fotos"
    /// Claves por petición al marcar borrados (van en la URL).
    static let clavesPorPeticion = 100

    let cliente: SupabaseClient

    public init(cliente: SupabaseClient) {
        self.cliente = cliente
    }

    public func subir<F: FilaRemota>(_ filas: [F]) async throws -> [ClaveFila: Date] {
        guard !filas.isEmpty else { return [:] }
        let respuesta: [F] = try await cliente
            .from(F.tabla.rawValue)
            .upsert(filas, onConflict: F.tabla.columnasClave.joined(separator: ","), returning: .representation)
            .execute()
            .value
        return Self.fechas(respuesta)
    }

    public func marcarBorradas<F: FilaRemota>(_ tipo: F.Type, claves: [ClaveFila], fecha: Date) async throws -> [ClaveFila: Date] {
        let cambio = Borrado(borradoEn: fecha)
        var resultado: [ClaveFila: Date] = [:]
        if F.tabla.columnasClave.count == 1 {
            var inicio = 0
            while inicio < claves.count {
                let lote = claves[inicio ..< min(inicio + Self.clavesPorPeticion, claves.count)]
                let respuesta: [F] = try await cliente
                    .from(F.tabla.rawValue)
                    .update(cambio, returning: .representation)
                    .in("id", values: lote.compactMap { $0.valores.first?.uuidString.lowercased() })
                    .execute()
                    .value
                resultado.merge(Self.fechas(respuesta)) { _, nueva in nueva }
                inicio += Self.clavesPorPeticion
            }
        } else {
            // lista_restaurantes: clave doble, una petición por par (son pocas).
            for clave in claves where clave.valores.count == 2 {
                let respuesta: [F] = try await cliente
                    .from(F.tabla.rawValue)
                    .update(cambio, returning: .representation)
                    .eq("lista_id", value: clave.valores[0].uuidString.lowercased())
                    .eq("restaurante_id", value: clave.valores[1].uuidString.lowercased())
                    .execute()
                    .value
                resultado.merge(Self.fechas(respuesta)) { _, nueva in nueva }
            }
        }
        return resultado
    }

    public func bajar<F: FilaRemota>(_ tipo: F.Type, cambiadasDesde: Date?, posicion: Int, limite: Int) async throws -> [F] {
        var consulta = cliente.from(F.tabla.rawValue).select()
        if let cambiadasDesde {
            consulta = consulta.gt("actualizado_en", value: cambiadasDesde)
        } else {
            consulta = consulta.filter("borrado_en", operator: "is", value: "null")
        }
        var ordenada = consulta.order("actualizado_en", ascending: true)
        for columna in F.tabla.columnasClave {
            ordenada = ordenada.order(columna, ascending: true)
        }
        return try await ordenada
            .range(from: posicion, to: posicion + limite - 1)
            .execute()
            .value
    }

    public func subirImagen(_ datos: Data, ruta: String) async throws {
        _ = try await cliente.storage
            .from(Self.bucket)
            .upload(ruta, data: datos, options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    public func bajarImagen(ruta: String) async throws -> Data {
        try await cliente.storage.from(Self.bucket).download(path: ruta)
    }

    public func borrarImagenes(rutas: [String]) async throws {
        guard !rutas.isEmpty else { return }
        _ = try await cliente.storage.from(Self.bucket).remove(paths: rutas)
    }

    // MARK: Ayudas

    private struct Borrado: Encodable, Sendable {
        let borradoEn: Date
        enum CodingKeys: String, CodingKey { case borradoEn = "borrado_en" }
    }

    static func fechas<F: FilaRemota>(_ filas: [F]) -> [ClaveFila: Date] {
        var resultado: [ClaveFila: Date] = [:]
        for fila in filas {
            if let fecha = fila.actualizadoEn { resultado[fila.clave] = fecha }
        }
        return resultado
    }
}
