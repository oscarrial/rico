import CryptoKit
import Foundation
import SwiftData
import Modelos
import RicoCore

/// Una vuelta de sincronización de la base de una cuenta: detectar cambios locales, bajar los
/// del servidor, subir borrados y cambios. Ver docs/decisiones/0004-sincronizacion.md.
@MainActor
public final class MotorSincronizacion {
    public let usuario: UUID
    let contexto: ModelContext
    let servicio: any ServicioSincronizacion
    let reloj: () -> Date

    /// `true` mientras el motor guarda: esos guardados no son cambios del usuario.
    public private(set) var guardando = false

    /// Se pide desde la marca menos este margen para no perder filas que confirmaron tarde.
    static let margenBajada: TimeInterval = 120
    static let filasPorPagina = 500
    static let filasPorLote = 200
    static let miniaturasPorVuelta = 40

    private var indice = IndiceLocal()

    public init(
        contexto: ModelContext,
        servicio: any ServicioSincronizacion,
        usuario: UUID,
        reloj: @escaping () -> Date = { Date() }
    ) {
        self.contexto = contexto
        self.servicio = servicio
        self.usuario = usuario
        self.reloj = reloj
    }

    /// Vuelta completa. Lanza el primer error de conexión; los rechazos de filas concretas
    /// se registran y esas filas quedan pendientes.
    public func sincronizar() async throws {
        try detectarCambios()
        try await bajarCambios()
        try detectarCambios()
        try await subirBorrados()
        try await subirCambios()
    }

    /// Hay cambios o borrados locales sin subir (según la última detección).
    public func hayPendientes() throws -> Bool {
        try contexto.fetch(FetchDescriptor<RegistroSincronizado>()).contains { $0.pendiente }
    }

    // MARK: - Detección de cambios locales

    typealias Instantanea = [TablaRemota: [String: any FilaRemota]]

    /// Compara cada fila local con su registro y anota cambios y borrados pendientes.
    public func detectarCambios() throws {
        let locales = try instantanea()
        var registros = try registrosPorLlave()
        let ahora = reloj()

        for (tabla, filas) in locales {
            for (clave, fila) in filas {
                let llave = Self.llave(tabla.rawValue, clave)
                let registro: RegistroSincronizado
                if let existente = registros.removeValue(forKey: llave) {
                    registro = existente
                } else {
                    registro = RegistroSincronizado(tabla: tabla.rawValue, clave: clave)
                    contexto.insert(registro)
                }
                if registro.borradoEnLocal != nil { registro.borradoEnLocal = nil }
                if registro.huella == huella(fila) {
                    if registro.cambiadoEnLocal != nil { registro.cambiadoEnLocal = nil }
                } else if registro.cambiadoEnLocal == nil {
                    registro.cambiadoEnLocal = ahora
                }
            }
        }

        // Registros sin fila local: borrados (también en cascada) desde la última vez.
        for registro in registros.values {
            if registro.huella == nil {
                contexto.delete(registro)
            } else if registro.borradoEnLocal == nil {
                registro.borradoEnLocal = ahora
                registro.cambiadoEnLocal = nil
            }
        }
        try guardar()
    }

    /// Todas las filas locales tal como se subirían, por tabla y clave.
    func instantanea() throws -> Instantanea {
        var filas: Instantanea = [:]
        let usuario = usuario
        func meter<F: FilaRemota>(_ fila: F?) {
            guard let fila else { return }
            filas[F.tabla, default: [:]][fila.clave.texto] = fila
        }
        for m in try contexto.fetch(FetchDescriptor<Restaurante>()) { meter(RestauranteRemoto(m, usuario: usuario)) }
        for m in try contexto.fetch(FetchDescriptor<PagoCapturado>()) { meter(PagoRemoto(m, usuario: usuario)) }
        let listas = try contexto.fetch(FetchDescriptor<Lista>())
        for m in listas { meter(ListaRemota(m, usuario: usuario)) }
        for m in try contexto.fetch(FetchDescriptor<Visita>()) { meter(VisitaRemota(m, usuario: usuario)) }
        for m in try contexto.fetch(FetchDescriptor<Plato>()) { meter(PlatoRemoto(m, usuario: usuario)) }
        for m in try contexto.fetch(FetchDescriptor<Foto>()) { meter(FotoRemota(m, usuario: usuario)) }
        for lista in listas {
            for restaurante in lista.restaurantes ?? [] {
                meter(ListaRestauranteRemota(lista: lista, restaurante: restaurante, usuario: usuario))
            }
        }
        for m in try contexto.fetch(FetchDescriptor<AliasComercio>()) { meter(AliasRemoto(m, usuario: usuario)) }
        return filas
    }

    // MARK: - Bajada

    func bajarCambios() async throws {
        try await bajar(RestauranteRemoto.self, aplicar: aplicar)
        try await bajar(PagoRemoto.self, aplicar: aplicar)
        try await bajar(ListaRemota.self, aplicar: aplicar)
        try await bajar(VisitaRemota.self, aplicar: aplicar)
        try await bajar(PlatoRemoto.self, aplicar: aplicar)
        try await bajar(FotoRemota.self, aplicar: aplicar)
        try await bajar(ListaRestauranteRemota.self, aplicar: aplicar)
        try await bajar(AliasRemoto.self, aplicar: aplicar)
        try fusionarQuieroProbar()
    }

    /// Baja por páginas lo cambiado desde la marca de la tabla y lo aplica según «gana la última
    /// escritura». `aplicar` devuelve la huella de la fila local resultante (`nil` si no queda).
    private func bajar<F: FilaRemota>(_ tipo: F.Type, aplicar: (F) throws -> String?) async throws {
        let marcaTabla = try marca(de: F.tabla)
        let desde = marcaTabla.fecha.map { $0.addingTimeInterval(-Self.margenBajada) }
        var masReciente = marcaTabla.fecha
        var posicion = 0

        while true {
            try Task.checkCancellation()
            let filas = try await servicio.bajar(F.self, cambiadasDesde: desde, posicion: posicion, limite: Self.filasPorPagina)
            indice = try IndiceLocal(contexto)
            var registros = try registrosPorLlave()

            for fila in filas {
                guard let actualizado = fila.actualizadoEn else { continue }
                if masReciente.map({ actualizado > $0 }) ?? true { masReciente = actualizado }

                let llave = Self.llave(F.tabla.rawValue, fila.clave.texto)
                let registro = registros[llave]
                // Ya aplicada (o eco de una subida propia).
                if let conocida = registro?.actualizadoEnServidor, actualizado <= conocida.addingTimeInterval(0.001) {
                    continue
                }
                // Cambio local posterior: gana lo local y se subirá.
                if let local = registro?.cambiadoEnLocal ?? registro?.borradoEnLocal, local > actualizado {
                    continue
                }

                if let huella = try aplicar(fila) {
                    let actual: RegistroSincronizado
                    if let registro {
                        actual = registro
                    } else {
                        actual = RegistroSincronizado(tabla: F.tabla.rawValue, clave: fila.clave.texto)
                        contexto.insert(actual)
                        registros[llave] = actual
                    }
                    actual.huella = huella
                    actual.actualizadoEnServidor = actualizado
                    actual.cambiadoEnLocal = nil
                    actual.borradoEnLocal = nil
                } else if let registro {
                    contexto.delete(registro)
                    registros[llave] = nil
                }
            }
            try guardar()
            posicion += filas.count
            if filas.count < Self.filasPorPagina { break }
        }

        if masReciente != marcaTabla.fecha {
            marcaTabla.fecha = masReciente
            try guardar()
        }
    }

    private func aplicar(_ f: RestauranteRemoto) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.restaurantes.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        let m: Restaurante
        if let existente = indice.restaurantes[f.id] {
            m = existente
        } else {
            m = Restaurante(nombre: f.nombre)
            m.id = f.id
            contexto.insert(m)
            indice.restaurantes[f.id] = m
        }
        f.volcar(en: m)
        return huella(RestauranteRemoto(m, usuario: usuario))
    }

    private func aplicar(_ f: PagoRemoto) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.pagos.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        let m: PagoCapturado
        if let existente = indice.pagos[f.id] {
            m = existente
        } else {
            m = PagoCapturado(comercioBruto: f.comercioBruto, importe: Importe(centimos: f.importeCentimos, divisa: f.divisa))
            m.id = f.id
            contexto.insert(m)
            indice.pagos[f.id] = m
        }
        f.volcar(en: m)
        return huella(PagoRemoto(m, usuario: usuario))
    }

    private func aplicar(_ f: ListaRemota) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.listas.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        let m: Lista
        if let existente = indice.listas[f.id] {
            m = existente
        } else {
            m = Lista(nombre: f.nombre, tipo: TipoLista(rawValue: f.tipo) ?? .propia)
            m.id = f.id
            contexto.insert(m)
            indice.listas[f.id] = m
        }
        f.volcar(en: m)
        return huella(ListaRemota(m, usuario: usuario))
    }

    private func aplicar(_ f: VisitaRemota) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.visitas.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        let m: Visita
        if let existente = indice.visitas[f.id] {
            m = existente
        } else {
            m = Visita(fecha: f.fecha)
            m.id = f.id
            contexto.insert(m)
            indice.visitas[f.id] = m
        }
        f.volcar(en: m)
        let restaurante = f.restauranteID.flatMap { indice.restaurantes[$0] }
        if m.restaurante !== restaurante { m.restaurante = restaurante }
        let pago = f.pagoID.flatMap { indice.pagos[$0] }
        if m.pago !== pago { m.pago = pago }
        return huella(VisitaRemota(m, usuario: usuario))
    }

    private func aplicar(_ f: PlatoRemoto) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.platos.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        guard let visita = indice.visitas[f.visitaID] else { return nil }
        let m: Plato
        if let existente = indice.platos[f.id] {
            m = existente
        } else {
            m = Plato(nombre: f.nombre, orden: f.orden)
            m.id = f.id
            contexto.insert(m)
            indice.platos[f.id] = m
        }
        f.volcar(en: m)
        if m.visita !== visita { m.visita = visita }
        return PlatoRemoto(m, usuario: usuario).map { huella($0) }
    }

    private func aplicar(_ f: FotoRemota) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.fotos.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        guard let visita = indice.visitas[f.visitaID] else { return nil }
        let m: Foto
        if let existente = indice.fotos[f.id] {
            m = existente
        } else {
            m = Foto(datos: nil, miniatura: nil, fecha: f.fecha, orden: f.orden)
            m.id = f.id
            contexto.insert(m)
            indice.fotos[f.id] = m
        }
        f.volcar(en: m)
        if m.visita !== visita { m.visita = visita }
        let plato = f.platoID.flatMap { indice.platos[$0] }
        if m.plato !== plato { m.plato = plato }
        return FotoRemota(m, usuario: usuario).map { huella($0) }
    }

    private func aplicar(_ f: ListaRestauranteRemota) throws -> String? {
        guard let lista = indice.listas[f.listaID], let restaurante = indice.restaurantes[f.restauranteID] else {
            return nil
        }
        if f.borradoEn != nil {
            if lista.contiene(restaurante) {
                lista.restaurantes = (lista.restaurantes ?? []).filter { $0.id != restaurante.id }
            }
            return nil
        }
        if !lista.contiene(restaurante) {
            var actuales = lista.restaurantes ?? []
            actuales.append(restaurante)
            lista.restaurantes = actuales
        }
        return huella(ListaRestauranteRemota(lista: lista, restaurante: restaurante, usuario: usuario))
    }

    private func aplicar(_ f: AliasRemoto) throws -> String? {
        if f.borradoEn != nil {
            if let m = indice.alias.removeValue(forKey: f.id) { contexto.delete(m) }
            return nil
        }
        guard let restaurante = indice.restaurantes[f.restauranteID] else { return nil }
        let m: AliasComercio
        if let existente = indice.alias[f.id] {
            m = existente
        } else {
            m = AliasComercio(comercioLimpio: f.comercioLimpio, restaurante: restaurante)
            m.id = f.id
            contexto.insert(m)
            indice.alias[f.id] = m
        }
        f.volcar(en: m)
        if m.restaurante !== restaurante { m.restaurante = restaurante }
        return AliasRemoto(m, usuario: usuario).map { huella($0) }
    }

    /// Si este iPhone creó su «Quiero probar» antes de bajar la de la cuenta, hay dos: se queda
    /// la de id menor (la misma en todos los dispositivos) con los restaurantes de las demás.
    func fusionarQuieroProbar() throws {
        let tipo = TipoLista.quieroProbar.rawValue
        let todas = try contexto.fetch(FetchDescriptor<Lista>(predicate: #Predicate { $0.tipoRaw == tipo }))
        let ordenadas = todas.sorted { $0.id.uuidString < $1.id.uuidString }
        guard let principal = ordenadas.first, ordenadas.count > 1 else { return }
        var restaurantes = principal.restaurantes ?? []
        for otra in ordenadas.dropFirst() {
            for restaurante in otra.restaurantes ?? [] where !restaurantes.contains(where: { $0.id == restaurante.id }) {
                restaurantes.append(restaurante)
            }
            otra.restaurantes = []
            contexto.delete(otra)
        }
        principal.restaurantes = restaurantes
        try guardar()
    }

    // MARK: - Subida

    /// Borrados lógicos (`borrado_en`). Van antes que los cambios para liberar valores únicos.
    func subirBorrados() async throws {
        let pendientes = try contexto.fetch(FetchDescriptor<RegistroSincronizado>())
            .filter { $0.borradoEnLocal != nil && $0.huella != nil }
        let porTabla = Dictionary(grouping: pendientes, by: \.tabla)

        for tabla in TablaRemota.ordenSubida.reversed() {
            guard let registros = porTabla[tabla.rawValue], !registros.isEmpty else { continue }
            try Task.checkCancellation()
            let textos = Set(registros.map(\.clave))
            let claves = textos.compactMap { ClaveFila(texto: $0) }
            do {
                _ = try await marcarBorradas(Self.tipo(de: tabla), claves: claves)
            } catch {
                if esErrorDeConexion(error) || error is CancellationError { throw error }
                Registro.sincronizacion.error("No se pudieron borrar filas de \(tabla.rawValue, privacy: .public): \(String(describing: error), privacy: .private)")
                continue
            }
            for registro in try contexto.fetch(FetchDescriptor<RegistroSincronizado>())
            where registro.tabla == tabla.rawValue && registro.borradoEnLocal != nil && textos.contains(registro.clave) {
                contexto.delete(registro)
            }
            try guardar()

            if tabla == .fotos {
                let rutas = claves.compactMap(\.valores.first).flatMap { id -> [String] in
                    let par = FotoRemota.rutas(usuario: usuario, foto: id)
                    return [par.imagen, par.miniatura]
                }
                do {
                    try await servicio.borrarImagenes(rutas: rutas)
                } catch {
                    Registro.sincronizacion.notice("No se pudieron borrar imágenes: \(String(describing: error), privacy: .private)")
                }
            }
        }
    }

    private func marcarBorradas<F: FilaRemota>(_ tipo: F.Type, claves: [ClaveFila]) async throws -> [ClaveFila: Date] {
        try await servicio.marcarBorradas(tipo, claves: claves, fecha: reloj())
    }

    /// Cambios en el orden de las claves externas. Las fotos suben antes su imagen.
    func subirCambios() async throws {
        let locales = try instantanea()
        for tabla in TablaRemota.ordenSubida {
            try Task.checkCancellation()
            let filas = locales[tabla] ?? [:]
            var permitidas: Set<String>?
            if tabla == .fotos {
                permitidas = try await subirImagenesPendientes()
            }
            try await subirPendientes(Self.tipo(de: tabla), locales: filas, permitidas: permitidas)
        }
    }

    private func subirPendientes<F: FilaRemota>(
        _ tipo: F.Type,
        locales: [String: any FilaRemota],
        permitidas: Set<String>?
    ) async throws {
        let claves = try contexto.fetch(FetchDescriptor<RegistroSincronizado>())
            .filter { $0.tabla == F.tabla.rawValue && $0.cambiadoEnLocal != nil }
            .map(\.clave)
            .filter { permitidas?.contains($0) ?? true }
            .sorted()
        let filas = claves.compactMap { locales[$0] as? F }
        guard !filas.isEmpty else { return }

        var inicio = 0
        while inicio < filas.count {
            let lote = Array(filas[inicio ..< min(inicio + Self.filasPorLote, filas.count)])
            inicio += Self.filasPorLote
            let huellas = lote.map { huella($0) }
            do {
                let fechas = try await servicio.subir(lote)
                try confirmar(lote, huellas: huellas, fechas: fechas)
            } catch {
                if esErrorDeConexion(error) || error is CancellationError { throw error }
                Registro.sincronizacion.notice("Lote de \(F.tabla.rawValue, privacy: .public) rechazado; se prueba fila a fila: \(String(describing: error), privacy: .private)")
                // Una fila mala no debe parar a las demás.
                for (fila, huella) in zip(lote, huellas) {
                    do {
                        let fechas = try await servicio.subir([fila])
                        try confirmar([fila], huellas: [huella], fechas: fechas)
                    } catch {
                        if esErrorDeConexion(error) || error is CancellationError { throw error }
                        Registro.sincronizacion.error("Fila de \(F.tabla.rawValue, privacy: .public) rechazada (\(fila.clave.texto, privacy: .private)): \(String(describing: error), privacy: .private)")
                    }
                }
            }
        }
    }

    private func confirmar<F: FilaRemota>(_ lote: [F], huellas: [String], fechas: [ClaveFila: Date]) throws {
        let registros = try registrosPorLlave()
        for (fila, huella) in zip(lote, huellas) {
            guard let registro = registros[Self.llave(F.tabla.rawValue, fila.clave.texto)] else { continue }
            registro.huella = huella
            if let fecha = fechas[fila.clave] { registro.actualizadoEnServidor = fecha }
            registro.cambiadoEnLocal = nil
        }
        try guardar()
    }

    /// Sube al bucket la imagen y la miniatura de las fotos pendientes que aún no las tienen.
    /// Devuelve las claves de las fotos que ya pueden subir su fila.
    private func subirImagenesPendientes() async throws -> Set<String> {
        let pendientes = try contexto.fetch(FetchDescriptor<RegistroSincronizado>())
            .filter { $0.tabla == TablaRemota.fotos.rawValue && $0.cambiadoEnLocal != nil }
            .map(\.clave)
        guard !pendientes.isEmpty else { return [] }
        let fotos = try IndiceLocal.porID(contexto, \Foto.id)
        var listas: Set<String> = []

        for clave in pendientes.sorted() {
            guard let id = ClaveFila(texto: clave)?.valores.first, let foto = fotos[id] else { continue }
            if foto.rutaRemota != nil, foto.rutaMiniaturaRemota != nil {
                listas.insert(clave)
                continue
            }
            guard let imagen = foto.datos ?? foto.miniatura, let miniatura = foto.miniatura ?? foto.datos else { continue }
            let rutas = FotoRemota.rutas(usuario: usuario, foto: id)
            do {
                try await servicio.subirImagen(imagen, ruta: rutas.imagen)
                try await servicio.subirImagen(miniatura, ruta: rutas.miniatura)
            } catch {
                if esErrorDeConexion(error) || error is CancellationError { throw error }
                Registro.sincronizacion.error("No se pudo subir la imagen \(clave, privacy: .private): \(String(describing: error), privacy: .private)")
                continue
            }
            guard !foto.isDeleted else { continue }
            foto.rutaRemota = rutas.imagen
            foto.rutaMiniaturaRemota = rutas.miniatura
            try guardar()
            listas.insert(clave)
        }
        return listas
    }

    // MARK: - Imágenes bajadas

    /// Baja las miniaturas de las fotos que vinieron del servidor sin imagen.
    public func bajarMiniaturasQueFaltan() async {
        var descriptor = FetchDescriptor<Foto>(predicate: #Predicate { $0.rutaMiniaturaRemota != nil && $0.miniatura == nil })
        descriptor.fetchLimit = Self.miniaturasPorVuelta
        let fotos: [Foto]
        do {
            fotos = try contexto.fetch(descriptor)
        } catch {
            Registro.sincronizacion.error("No se pudieron buscar miniaturas: \(String(describing: error), privacy: .private)")
            return
        }
        for foto in fotos {
            guard let ruta = foto.rutaMiniaturaRemota else { continue }
            do {
                let datos = try await servicio.bajarImagen(ruta: ruta)
                guard !foto.isDeleted else { continue }
                foto.miniatura = datos
                try guardar()
            } catch {
                Registro.sincronizacion.notice("No se pudo bajar una miniatura: \(String(describing: error), privacy: .private)")
                if esErrorDeConexion(error) { return }
            }
        }
    }

    /// Baja la imagen completa de una foto que vino del servidor solo con miniatura.
    public func bajarImagenCompleta(de foto: Foto) async throws {
        guard foto.datos == nil, let ruta = foto.rutaRemota else { return }
        let datos = try await servicio.bajarImagen(ruta: ruta)
        guard !foto.isDeleted else { return }
        foto.datos = datos
        try guardar()
    }

    // MARK: - Ayudas

    static func tipo(de tabla: TablaRemota) -> any FilaRemota.Type {
        switch tabla {
        case .restaurantes: RestauranteRemoto.self
        case .pagosCapturados: PagoRemoto.self
        case .listas: ListaRemota.self
        case .visitas: VisitaRemota.self
        case .platos: PlatoRemoto.self
        case .fotos: FotoRemota.self
        case .listaRestaurantes: ListaRestauranteRemota.self
        case .aliasComercio: AliasRemoto.self
        }
    }

    static func llave(_ tabla: String, _ clave: String) -> String { "\(tabla)/\(clave)" }

    private func registrosPorLlave() throws -> [String: RegistroSincronizado] {
        var resultado: [String: RegistroSincronizado] = [:]
        for registro in try contexto.fetch(FetchDescriptor<RegistroSincronizado>()) {
            let llave = Self.llave(registro.tabla, registro.clave)
            if resultado[llave] == nil {
                resultado[llave] = registro
            } else {
                contexto.delete(registro)
            }
        }
        return resultado
    }

    private func marca(de tabla: TablaRemota) throws -> MarcaBajada {
        let nombre = tabla.rawValue
        let existentes = try contexto.fetch(FetchDescriptor<MarcaBajada>(predicate: #Predicate { $0.tabla == nombre }))
        if let marca = existentes.first { return marca }
        let nueva = MarcaBajada(tabla: nombre)
        contexto.insert(nueva)
        return nueva
    }

    func guardar() throws {
        guard contexto.hasChanges else { return }
        guardando = true
        defer { guardando = false }
        try contexto.save()
    }

    /// Codificador estable para las huellas: claves ordenadas y fechas en milisegundos.
    private static let codificadorHuella: JSONEncoder = {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.sortedKeys]
        codificador.dateEncodingStrategy = .custom { fecha, encoder in
            var contenedor = encoder.singleValueContainer()
            try contenedor.encode((fecha.timeIntervalSince1970 * 1000).rounded())
        }
        return codificador
    }()

    /// SHA-256 del JSON que se subiría.
    func huella(_ fila: some FilaRemota) -> String {
        let datos = (try? Self.codificadorHuella.encode(fila)) ?? Data()
        return SHA256.hash(data: datos).map { String(format: "%02x", $0) }.joined()
    }
}

/// Modelos locales por id, para resolver relaciones al aplicar filas bajadas.
struct IndiceLocal {
    var restaurantes: [UUID: Restaurante] = [:]
    var pagos: [UUID: PagoCapturado] = [:]
    var listas: [UUID: Lista] = [:]
    var visitas: [UUID: Visita] = [:]
    var platos: [UUID: Plato] = [:]
    var fotos: [UUID: Foto] = [:]
    var alias: [UUID: AliasComercio] = [:]

    init() {}

    init(_ contexto: ModelContext) throws {
        restaurantes = try Self.porID(contexto, \Restaurante.id)
        pagos = try Self.porID(contexto, \PagoCapturado.id)
        listas = try Self.porID(contexto, \Lista.id)
        visitas = try Self.porID(contexto, \Visita.id)
        platos = try Self.porID(contexto, \Plato.id)
        fotos = try Self.porID(contexto, \Foto.id)
        alias = try Self.porID(contexto, \AliasComercio.id)
    }

    static func porID<T: PersistentModel>(_ contexto: ModelContext, _ id: KeyPath<T, UUID>) throws -> [UUID: T] {
        var resultado: [UUID: T] = [:]
        for modelo in try contexto.fetch(FetchDescriptor<T>()) where resultado[modelo[keyPath: id]] == nil {
            resultado[modelo[keyPath: id]] = modelo
        }
        return resultado
    }
}
