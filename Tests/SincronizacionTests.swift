import Foundation
import SwiftData
import Testing
import Modelos
import RicoCore
import Sincronizacion

// MARK: - Servidor falso

/// Supabase en memoria: guarda las filas tal cual, pone `actualizado_en` con su reloj y
/// anota el orden de las subidas.
final class ServidorFalso: ServicioSincronizacion, @unchecked Sendable {
    private let cerrojo = NSLock()
    private var filas: [TablaRemota: [ClaveFila: any FilaRemota]] = [:]
    private var _subidas: [(tabla: TablaRemota, claves: [ClaveFila])] = []
    private var _borradas: [(tabla: TablaRemota, claves: [ClaveFila])] = []
    private var _imagenes: [String: Data] = [:]
    private var ultimaFecha = Date(timeIntervalSince1970: 1_800_000_000)

    /// Reloj del servidor: cada escritura avanza al menos 1 ms y nunca va hacia atrás.
    var ahora = Date(timeIntervalSince1970: 1_800_000_000)

    private func conCerrojo<T>(_ cuerpo: () throws -> T) rethrows -> T {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return try cuerpo()
    }

    private func siguienteFecha() -> Date {
        let fecha = max(ahora, ultimaFecha.addingTimeInterval(0.001))
        ultimaFecha = fecha
        return fecha
    }

    // Lo que ven las pruebas

    var subidas: [(tabla: TablaRemota, claves: [ClaveFila])] { conCerrojo { _subidas } }
    var borradas: [(tabla: TablaRemota, claves: [ClaveFila])] { conCerrojo { _borradas } }
    var imagenes: [String: Data] { conCerrojo { _imagenes } }

    func fila<F: FilaRemota>(_ tipo: F.Type, _ clave: ClaveFila) -> F? {
        conCerrojo { filas[F.tabla]?[clave] as? F }
    }

    func todas<F: FilaRemota>(_ tipo: F.Type) -> [F] {
        conCerrojo { (filas[F.tabla] ?? [:]).values.compactMap { $0 as? F } }
    }

    /// Escritura de otro dispositivo: guarda la fila con fecha nueva del servidor.
    @discardableResult
    func escribir<F: FilaRemota>(_ fila: F) -> F {
        conCerrojo {
            var copia = fila
            copia.actualizadoEn = siguienteFecha()
            filas[F.tabla, default: [:]][copia.clave] = copia
            return copia
        }
    }

    func ponerImagen(_ datos: Data, ruta: String) {
        conCerrojo { _imagenes[ruta] = datos }
    }

    // ServicioSincronizacion

    func subir<F: FilaRemota>(_ lote: [F]) async throws -> [ClaveFila: Date] {
        conCerrojo {
            var resultado: [ClaveFila: Date] = [:]
            for fila in lote {
                var copia = fila
                copia.actualizadoEn = siguienteFecha()
                copia.borradoEn = nil
                filas[F.tabla, default: [:]][copia.clave] = copia
                resultado[copia.clave] = copia.actualizadoEn
            }
            _subidas.append((F.tabla, lote.map(\.clave)))
            return resultado
        }
    }

    func marcarBorradas<F: FilaRemota>(_ tipo: F.Type, claves: [ClaveFila], fecha: Date) async throws -> [ClaveFila: Date] {
        conCerrojo {
            var resultado: [ClaveFila: Date] = [:]
            for clave in claves {
                guard var fila = filas[F.tabla]?[clave] else { continue }
                fila.borradoEn = fecha
                fila.actualizadoEn = siguienteFecha()
                filas[F.tabla]?[clave] = fila
                resultado[clave] = fila.actualizadoEn
            }
            _borradas.append((F.tabla, claves))
            return resultado
        }
    }

    func bajar<F: FilaRemota>(_ tipo: F.Type, cambiadasDesde: Date?, posicion: Int, limite: Int) async throws -> [F] {
        conCerrojo {
            let todas = (filas[F.tabla] ?? [:]).values.compactMap { $0 as? F }
                .filter { fila in
                    if let cambiadasDesde { return (fila.actualizadoEn ?? .distantPast) > cambiadasDesde }
                    return fila.borradoEn == nil
                }
                .sorted { ($0.actualizadoEn ?? .distantPast, $0.clave.texto) < ($1.actualizadoEn ?? .distantPast, $1.clave.texto) }
            return Array(todas.dropFirst(posicion).prefix(limite))
        }
    }

    func subirImagen(_ datos: Data, ruta: String) async throws {
        conCerrojo { _imagenes[ruta] = datos }
    }

    func bajarImagen(ruta: String) async throws -> Data {
        guard let datos = conCerrojo({ _imagenes[ruta] }) else { throw URLError(.fileDoesNotExist) }
        return datos
    }

    func borrarImagenes(rutas: [String]) async throws {
        conCerrojo { for ruta in rutas { _imagenes[ruta] = nil } }
    }
}

/// Reloj del iPhone que controlan las pruebas.
@MainActor
final class RelojFalso {
    var ahora = Date(timeIntervalSince1970: 1_800_000_000)
    func avanzar(_ segundos: TimeInterval) { ahora = ahora.addingTimeInterval(segundos) }
}

// MARK: - Pruebas

@MainActor
@Suite("Sincronización")
struct SincronizacionTests {
    let usuario = UUID()
    let servidor = ServidorFalso()
    let reloj = RelojFalso()
    let contenedor: ModelContainer
    let contexto: ModelContext
    let motor: MotorSincronizacion
    /// Base de otro iPhone de la misma cuenta. Se guarda aquí porque un `ModelContext`
    /// no mantiene vivo su contenedor.
    let otroContenedor: ModelContainer

    init() throws {
        contenedor = try ContenedorRico.crear(enMemoria: true)
        contexto = contenedor.mainContext
        otroContenedor = try ContenedorRico.crear(enMemoria: true)
        let reloj = reloj
        motor = MotorSincronizacion(contexto: contexto, servicio: servidor, usuario: usuario, reloj: { reloj.ahora })
    }

    /// Otro iPhone de la misma cuenta, con su propia base.
    private func otroDispositivo() throws -> (ModelContext, MotorSincronizacion) {
        let reloj = reloj
        let otroContexto = otroContenedor.mainContext
        let motor = MotorSincronizacion(contexto: otroContexto, servicio: servidor, usuario: usuario, reloj: { reloj.ahora })
        return (otroContexto, motor)
    }

    @discardableResult
    private func visitaCompleta(en contexto: ModelContext) throws -> Visita {
        let restaurante = Restaurante(nombre: "Taberna O Grelo")
        restaurante.ciudad = "Vigo"
        restaurante.latitud = 42.24
        restaurante.longitud = -8.72
        restaurante.web = URL(string: "https://ogrelo.example")
        contexto.insert(restaurante)
        let visita = Visita(fecha: Date(timeIntervalSince1970: 1_799_000_000))
        contexto.insert(visita)
        visita.restaurante = restaurante
        visita.estrellas = 4.5
        visita.estado = .valorada
        visita.importe = Importe(centimos: 4800, divisa: "EUR")
        visita.comensales = 2
        let plato = Plato(nombre: "Pulpo á feira", valoracion: .encanto, orden: 0)
        contexto.insert(plato)
        plato.visita = visita
        try contexto.save()
        return visita
    }

    private func unico<T: PersistentModel>(_ tipo: T.Type, en contexto: ModelContext? = nil) throws -> T? {
        try (contexto ?? self.contexto).fetch(FetchDescriptor<T>()).first
    }

    // MARK: Subida

    @Test func subeLoNuevo() async throws {
        let visita = try visitaCompleta(en: contexto)
        try await motor.sincronizar()

        let remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(visita.id)))
        #expect(remota.usuarioID == usuario)
        #expect(remota.restauranteID == visita.restaurante?.id)
        #expect(remota.estrellas == 4.5)
        #expect(remota.estado == "valorada")
        #expect(remota.importeCentimos == 4800)
        #expect(remota.comensales == 2)
        #expect(remota.borradoEn == nil)

        let restaurante = try #require(servidor.fila(RestauranteRemoto.self, ClaveFila(visita.restaurante!.id)))
        #expect(restaurante.nombre == "Taberna O Grelo")
        #expect(restaurante.web == "https://ogrelo.example")
        #expect(servidor.todas(PlatoRemoto.self).map(\.nombre) == ["Pulpo á feira"])
        #expect(try !motor.hayPendientes())
    }

    @Test func noResubeLoYaSubido() async throws {
        let visita = try visitaCompleta(en: contexto)
        try await motor.sincronizar()
        let subidasTrasLaPrimera = servidor.subidas.count

        try await motor.sincronizar()
        #expect(servidor.subidas.count == subidasTrasLaPrimera)

        // Solo sube lo que cambia.
        visita.resena = "El pulpo, de diez."
        try contexto.save()
        try await motor.sincronizar()
        let nuevas = servidor.subidas.dropFirst(subidasTrasLaPrimera)
        #expect(nuevas.map(\.tabla) == [.visitas])
        #expect(nuevas.first?.claves == [ClaveFila(visita.id)])
        #expect(servidor.fila(VisitaRemota.self, ClaveFila(visita.id))?.resena == "El pulpo, de diez.")
    }

    @Test func campoVaciadoSeSubeComoNull() async throws {
        let visita = try visitaCompleta(en: contexto)
        visita.resena = "Algo"
        try contexto.save()
        try await motor.sincronizar()

        visita.resena = nil
        try contexto.save()
        try await motor.sincronizar()
        #expect(servidor.fila(VisitaRemota.self, ClaveFila(visita.id))?.resena == nil)

        // Y el JSON lleva la clave con null (si no, el upsert no la vaciaría).
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(VisitaRemota(visita, usuario: usuario))) as? [String: Any]
        #expect(json?.keys.contains("resena") == true)
        #expect(json?["resena"] is NSNull)
    }

    @Test func ordenDeSubidaPorClavesExternas() async throws {
        let visita = try visitaCompleta(en: contexto)
        let pago = PagoCapturado(comercioBruto: "TABERNA O GRELO VIGO", importe: Importe(centimos: 4800, divisa: "EUR"))
        contexto.insert(pago)
        visita.pago = pago
        let foto = Foto(datos: Data([1, 2, 3]), miniatura: Data([4]), orden: 0)
        contexto.insert(foto)
        foto.visita = visita
        let lista = try contexto.crearLista(nombre: "Cenas", esPremium: true)
        try contexto.anadir(visita.restaurante!, a: lista)
        let alias = AliasComercio(comercioLimpio: "taberna o grelo", restaurante: visita.restaurante!)
        contexto.insert(alias)
        alias.restaurante = visita.restaurante
        try contexto.save()

        try await motor.sincronizar()

        let orden = servidor.subidas.map(\.tabla)
        #expect(orden == [.restaurantes, .pagosCapturados, .listas, .visitas, .platos, .fotos, .listaRestaurantes, .aliasComercio])
        #expect(servidor.fila(VisitaRemota.self, ClaveFila(visita.id))?.pagoID == pago.id)
        #expect(servidor.todas(ListaRestauranteRemota.self).map(\.clave) == [ClaveFila(lista.id, visita.restaurante!.id)])
    }

    @Test func fotosSubenSuImagenAlBucket() async throws {
        let visita = try visitaCompleta(en: contexto)
        let foto = Foto(datos: Data([1, 2, 3]), miniatura: Data([4]), orden: 0)
        contexto.insert(foto)
        foto.visita = visita
        try contexto.save()

        try await motor.sincronizar()

        let rutas = FotoRemota.rutas(usuario: usuario, foto: foto.id)
        #expect(rutas.imagen == "\(usuario.uuidString.lowercased())/\(foto.id.uuidString.lowercased()).jpg")
        #expect(servidor.imagenes[rutas.imagen] == Data([1, 2, 3]))
        #expect(servidor.imagenes[rutas.miniatura] == Data([4]))
        #expect(foto.rutaRemota == rutas.imagen)
        let remota = try #require(servidor.fila(FotoRemota.self, ClaveFila(foto.id)))
        #expect(remota.ruta == rutas.imagen)
        #expect(remota.rutaMiniatura == rutas.miniatura)
        #expect(remota.visitaID == visita.id)
    }

    // MARK: Bajada

    @Test func bajaYCreaEnUnIphoneNuevo() async throws {
        // El primer iPhone sube su diario…
        let (otroContexto, otroMotor) = try otroDispositivo()
        let original = try visitaCompleta(en: otroContexto)
        let foto = Foto(datos: Data([9, 9]), miniatura: Data([7]), orden: 0)
        otroContexto.insert(foto)
        foto.visita = original
        let quieroProbar = try otroContexto.listaQuieroProbar()
        try otroContexto.anadir(original.restaurante!, a: quieroProbar)
        try otroContexto.save()
        try await otroMotor.sincronizar()

        // …y el nuevo lo baja todo.
        try await motor.sincronizar()
        await motor.bajarMiniaturasQueFaltan()

        let visita = try #require(try unico(Visita.self))
        #expect(visita.id == original.id)
        #expect(visita.estrellas == 4.5)
        #expect(visita.restaurante?.nombre == "Taberna O Grelo")
        #expect(visita.restaurante?.web == URL(string: "https://ogrelo.example"))
        #expect(visita.platos?.map(\.nombre) == ["Pulpo á feira"])
        let fotoBajada = try #require(visita.fotos?.first)
        #expect(fotoBajada.miniatura == Data([7]))
        #expect(fotoBajada.datos == nil)
        let lista = try contexto.listaQuieroProbar()
        #expect(lista.id == quieroProbar.id)
        #expect(lista.restaurantes?.map(\.id) == [original.restaurante!.id])

        // Lo bajado no se vuelve a subir.
        let subidas = servidor.subidas.count
        try await motor.sincronizar()
        #expect(servidor.subidas.count == subidas)
        #expect(try !motor.hayPendientes())

        // La imagen completa, bajo demanda.
        try await motor.bajarImagenCompleta(de: fotoBajada)
        #expect(fotoBajada.datos == Data([9, 9]))
    }

    @Test func bajaYActualizaSiEsMasReciente() async throws {
        let visita = try visitaCompleta(en: contexto)
        try await motor.sincronizar()

        // Otro iPhone la cambia después.
        reloj.avanzar(60)
        servidor.ahora = reloj.ahora
        var remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(visita.id)))
        remota.estrellas = 3
        remota.resena = "Ha bajado"
        servidor.escribir(remota)

        try await motor.sincronizar()
        #expect(visita.estrellas == 3)
        #expect(visita.resena == "Ha bajado")
        #expect(try !motor.hayPendientes())
    }

    @Test func ganaLaUltimaEscritura() async throws {
        let visita = try visitaCompleta(en: contexto)
        try await motor.sincronizar()

        // Cambio remoto a los 60 s; cambio local a los 120 s (sin conexión entre medias).
        servidor.ahora = reloj.ahora.addingTimeInterval(60)
        var remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(visita.id)))
        remota.resena = "Remota"
        servidor.escribir(remota)
        reloj.avanzar(120)
        visita.resena = "Local"
        try contexto.save()
        try motor.detectarCambios()

        try await motor.sincronizar()
        #expect(visita.resena == "Local")
        #expect(servidor.fila(VisitaRemota.self, ClaveFila(visita.id))?.resena == "Local")

        // Al revés: cambio local a los 200 s y remoto a los 300 s → gana el remoto.
        reloj.avanzar(80)
        visita.resena = "Local 2"
        try contexto.save()
        try motor.detectarCambios()
        servidor.ahora = reloj.ahora.addingTimeInterval(100)
        remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(visita.id)))
        remota.resena = "Remota 2"
        servidor.escribir(remota)

        try await motor.sincronizar()
        #expect(visita.resena == "Remota 2")
        #expect(servidor.fila(VisitaRemota.self, ClaveFila(visita.id))?.resena == "Remota 2")
    }

    // MARK: Borrados

    @Test func borradoRemotoBorraEnLocal() async throws {
        let visita = try visitaCompleta(en: contexto)
        let id = visita.id
        try await motor.sincronizar()

        reloj.avanzar(60)
        servidor.ahora = reloj.ahora
        var remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(id)))
        remota.borradoEn = reloj.ahora
        servidor.escribir(remota)

        try await motor.sincronizar()
        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 0)
        // El plato cae en cascada en local y su borrado se sube.
        #expect(try contexto.fetchCount(FetchDescriptor<Plato>()) == 0)
        #expect(servidor.todas(PlatoRemoto.self).allSatisfy { $0.borradoEn != nil })
        #expect(try contexto.fetchCount(FetchDescriptor<Restaurante>()) == 1)
    }

    @Test func borradoLocalSeSubeComoBorradoEn() async throws {
        let visita = try visitaCompleta(en: contexto)
        let id = visita.id
        let plato = try #require(visita.platos?.first?.id)
        let restaurante = try #require(visita.restaurante?.id)
        try await motor.sincronizar()

        contexto.delete(visita)
        try contexto.save()
        try await motor.sincronizar()

        // Sigue en el servidor, marcada como borrada (y su plato, borrado en cascada).
        let remota = try #require(servidor.fila(VisitaRemota.self, ClaveFila(id)))
        #expect(remota.borradoEn != nil)
        #expect(servidor.fila(PlatoRemoto.self, ClaveFila(plato))?.borradoEn != nil)
        #expect(servidor.fila(RestauranteRemoto.self, ClaveFila(restaurante)) != nil)
        #expect(servidor.fila(RestauranteRemoto.self, ClaveFila(restaurante))?.borradoEn == nil)
        #expect(try !motor.hayPendientes())

        // Y otro iPhone no la recibe en su primera bajada.
        let (otroContexto, otroMotor) = try otroDispositivo()
        try await otroMotor.sincronizar()
        #expect(try otroContexto.fetchCount(FetchDescriptor<Visita>()) == 0)
        #expect(try otroContexto.fetchCount(FetchDescriptor<Restaurante>()) == 1)
    }

    @Test func borrarAntesDeSubirNoLlegaAlServidor() async throws {
        let restaurante = Restaurante(nombre: "Efímero")
        contexto.insert(restaurante)
        try contexto.save()
        try motor.detectarCambios()
        contexto.delete(restaurante)
        try contexto.save()

        try await motor.sincronizar()
        #expect(servidor.subidas.isEmpty)
        #expect(servidor.borradas.isEmpty)
        #expect(try contexto.fetchCount(FetchDescriptor<RegistroSincronizado>()) == 0)
    }

    @Test func quitarDeUnaListaSeSubeComoBorrado() async throws {
        let restaurante = Restaurante(nombre: "Casa Marcelo")
        contexto.insert(restaurante)
        let lista = try contexto.listaQuieroProbar()
        try contexto.anadir(restaurante, a: lista)
        try await motor.sincronizar()

        try contexto.quitar(restaurante, de: lista)
        try await motor.sincronizar()
        let par = try #require(servidor.fila(ListaRestauranteRemota.self, ClaveFila(lista.id, restaurante.id)))
        #expect(par.borradoEn != nil)

        // Volver a añadirlo (más tarde) lo revive.
        reloj.avanzar(10)
        try contexto.anadir(restaurante, a: lista)
        try await motor.sincronizar()
        #expect(servidor.fila(ListaRestauranteRemota.self, ClaveFila(lista.id, restaurante.id))?.borradoEn == nil)
    }

    @Test func dosQuieroProbarSeFusionan() async throws {
        let (otroContexto, otroMotor) = try otroDispositivo()
        let enOtro = Restaurante(nombre: "Bar Otro")
        otroContexto.insert(enOtro)
        try otroContexto.anadir(enOtro, a: try otroContexto.listaQuieroProbar())
        try await otroMotor.sincronizar()

        let aqui = Restaurante(nombre: "Bar Aquí")
        contexto.insert(aqui)
        try contexto.anadir(aqui, a: try contexto.listaQuieroProbar())
        try await motor.sincronizar()
        try await otroMotor.sincronizar()

        for c in [contexto, otroContexto] {
            let tipo = TipoLista.quieroProbar.rawValue
            let listas = try c.fetch(FetchDescriptor<Lista>(predicate: #Predicate { $0.tipoRaw == tipo }))
            #expect(listas.count == 1)
            #expect(Set(listas.first?.restaurantes?.map(\.nombre) ?? []) == ["Bar Otro", "Bar Aquí"])
        }
    }

    // MARK: DTO ↔ modelo

    @Test func filasIdaYVuelta() throws {
        let fecha = Date(timeIntervalSince1970: 1_799_000_000)
        let visita = try visitaCompleta(en: contexto)
        let restaurante = try #require(visita.restaurante)
        restaurante.mapItemID = "I-GRELO"
        restaurante.rangoPrecio = 2
        restaurante.fechaCreacion = fecha
        let pago = PagoCapturado(comercioBruto: "GRELO*VIGO", importe: Importe(centimos: 1250, divisa: "EUR"), fecha: fecha, tarjeta: "1234")
        pago.puntuacionEmparejado = 0.875
        pago.estado = .asignado
        contexto.insert(pago)
        visita.pago = pago
        visita.volveria = .si
        let plato = try #require(visita.platos?.first)
        plato.precioCentimos = 1800
        let foto = Foto(datos: nil, miniatura: Data([1]), fecha: fecha, orden: 2)
        contexto.insert(foto)
        foto.visita = visita
        foto.plato = plato
        let lista = Lista(nombre: "Cenas", tipo: .propia)
        lista.emoji = "🍷"
        lista.fechaCreacion = fecha
        contexto.insert(lista)
        let alias = AliasComercio(comercioLimpio: "grelo", restaurante: restaurante)
        contexto.insert(alias)
        alias.restaurante = restaurante
        try contexto.save()

        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        func idaYVuelta<F: FilaRemota>(_ fila: F) throws -> F {
            try decodificador.decode(F.self, from: codificador.encode(fila))
        }
        func claves(_ fila: some FilaRemota) throws -> Set<String> {
            let objeto = try JSONSerialization.jsonObject(with: codificador.encode(fila)) as? [String: Any]
            return Set((objeto ?? [:]).keys)
        }

        // Restaurante
        let r = RestauranteRemoto(restaurante, usuario: usuario)
        #expect(try idaYVuelta(r) == r)
        #expect(try claves(r) == ["id", "usuario_id", "nombre", "direccion", "ciudad", "pais", "latitud", "longitud", "map_item_id", "cocina", "rango_precio", "telefono", "web", "silenciado", "creado_en", "borrado_en"])
        let r2 = Restaurante(nombre: "")
        try idaYVuelta(r).volcar(en: r2)
        r2.id = restaurante.id
        #expect(RestauranteRemoto(r2, usuario: usuario) == r)

        // Pago
        let p = PagoRemoto(pago, usuario: usuario)
        #expect(try idaYVuelta(p) == p)
        #expect(try claves(p) == ["id", "usuario_id", "comercio_bruto", "comercio_limpio", "importe_centimos", "divisa", "tarjeta", "fecha", "latitud", "longitud", "puntuacion_emparejado", "estado", "borrado_en"])
        let p2 = PagoCapturado(comercioBruto: "", importe: Importe(centimos: 0, divisa: "EUR"))
        try idaYVuelta(p).volcar(en: p2)
        p2.id = pago.id
        #expect(PagoRemoto(p2, usuario: usuario) == p)

        // Visita
        let v = VisitaRemota(visita, usuario: usuario)
        #expect(try idaYVuelta(v) == v)
        #expect(try claves(v) == ["id", "usuario_id", "restaurante_id", "pago_id", "fecha", "estado", "estrellas", "resena", "volveria", "importe_centimos", "divisa", "comensales", "pague_todo", "ocasion", "origen", "creada_por_ia", "borrado_en"])
        #expect(v.volveria == "si")
        #expect(v.pagoID == pago.id)

        // Plato
        let pl = try #require(PlatoRemoto(plato, usuario: usuario))
        #expect(try idaYVuelta(pl) == pl)
        #expect(try claves(pl) == ["id", "usuario_id", "visita_id", "nombre", "valoracion", "precio_centimos", "nota", "orden", "borrado_en"])
        #expect(pl.valoracion == "encanto")

        // Foto
        let f = try #require(FotoRemota(foto, usuario: usuario))
        #expect(try idaYVuelta(f) == f)
        #expect(try claves(f) == ["id", "usuario_id", "visita_id", "plato_id", "ruta", "ruta_miniatura", "fecha", "es_comida", "plato_sugerido", "orden", "borrado_en"])
        #expect(f.platoID == plato.id)

        // Lista
        let l = ListaRemota(lista, usuario: usuario)
        #expect(try idaYVuelta(l) == l)
        #expect(try claves(l) == ["id", "usuario_id", "nombre", "emoji", "tipo", "orden", "compartida", "enlace_publico", "creado_en", "borrado_en"])
        #expect(l.tipo == "propia")

        // Lista ↔ restaurante
        let lr = ListaRestauranteRemota(lista: lista, restaurante: restaurante, usuario: usuario)
        #expect(try idaYVuelta(lr) == lr)
        #expect(try claves(lr) == ["lista_id", "restaurante_id", "usuario_id", "borrado_en"])
        #expect(lr.clave == ClaveFila(lista.id, restaurante.id))
        #expect(ClaveFila(texto: lr.clave.texto) == lr.clave)

        // Alias
        let a = try #require(AliasRemoto(alias, usuario: usuario))
        #expect(try idaYVuelta(a) == a)
        #expect(try claves(a) == ["id", "usuario_id", "comercio_limpio", "restaurante_id", "veces_confirmado", "borrado_en"])
    }

    @Test func leeLaRespuestaDelServidor() throws {
        // Respuesta de PostgREST tal cual (con columnas que no se envían).
        let json = """
        {"id":"6F1A1C2E-7E63-4C2B-9F4B-1D2E3F4A5B6C","usuario_id":"0B6E1C2E-7E63-4C2B-9F4B-1D2E3F4A5B6C",
         "restaurante_id":null,"pago_id":null,"fecha":"2026-10-20T21:30:00+00:00","estado":"valorada",
         "estrellas":4.5,"resena":null,"volveria":"quiza","importe_centimos":4800,"divisa":"EUR",
         "comensales":2,"pague_todo":true,"ocasion":null,"origen":"manual","creada_por_ia":false,
         "creado_en":"2026-10-20T21:31:00.123456+00:00","actualizado_en":"2026-10-20T21:31:00+00:00","borrado_en":null}
        """
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        let fila = try decodificador.decode(VisitaRemota.self, from: Data(json.utf8))
        #expect(fila.estrellas == 4.5)
        #expect(fila.volveria == "quiza")
        #expect(fila.actualizadoEn != nil)
        #expect(fila.borradoEn == nil)
        #expect(fila.restauranteID == nil)
    }

    // MARK: Sincronizador

    @Test func soloLocalNoHaceNada() async throws {
        try visitaCompleta(en: contexto)
        let sincronizador = Sincronizador(contexto: contexto, servicio: nil, usuario: nil)
        #expect(!sincronizador.activo)
        sincronizador.arrancar()
        await sincronizador.sincronizarAhora()
        #expect(sincronizador.ultimoGuardado == nil)
        #expect(try contexto.fetchCount(FetchDescriptor<RegistroSincronizado>()) == 0)
    }

    @Test func sincronizadorSubeYSePara() async throws {
        let preferencias = try #require(UserDefaults(suiteName: "pruebas-\(UUID().uuidString)"))
        try visitaCompleta(en: contexto)
        let sincronizador = Sincronizador(contexto: contexto, servicio: servidor, usuario: usuario, preferencias: preferencias, antirrebote: .seconds(60))
        #expect(sincronizador.activo)
        await sincronizador.sincronizarAhora()
        #expect(sincronizador.ultimoGuardado != nil)
        #expect(!sincronizador.hayPendientes)
        #expect(servidor.todas(VisitaRemota.self).count == 1)

        sincronizador.parar()
        #expect(!sincronizador.activo)
        let restaurante = Restaurante(nombre: "Tras parar")
        contexto.insert(restaurante)
        try contexto.save()
        await sincronizador.sincronizarAhora()
        #expect(servidor.fila(RestauranteRemoto.self, ClaveFila(restaurante.id)) == nil)
    }
}
