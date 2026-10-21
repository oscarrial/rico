import Foundation
import Modelos

// De los modelos de SwiftData a las filas del servidor y al revés. Las relaciones
// se resuelven fuera (en el motor), que es quien tiene los índices por id.

public extension RestauranteRemoto {
    init(_ m: Restaurante, usuario: UUID) {
        self.init(
            id: m.id, usuarioID: usuario, nombre: m.nombre, direccion: m.direccion, ciudad: m.ciudad,
            pais: m.pais, latitud: m.latitud, longitud: m.longitud, mapItemID: m.mapItemID,
            cocina: m.cocina, rangoPrecio: m.rangoPrecio, telefono: m.telefono,
            web: m.web?.absoluteString, silenciado: m.silenciado, creadoEn: m.fechaCreacion,
            actualizadoEn: nil, borradoEn: nil
        )
    }

    func volcar(en m: Restaurante) {
        m.nombre = nombre
        m.direccion = direccion
        m.ciudad = ciudad
        m.pais = pais
        m.latitud = latitud
        m.longitud = longitud
        m.mapItemID = mapItemID
        m.cocina = cocina
        m.rangoPrecio = rangoPrecio
        m.telefono = telefono
        m.web = web.flatMap(URL.init(string:))
        m.silenciado = silenciado
        if let creadoEn { m.fechaCreacion = creadoEn }
    }
}

public extension PagoRemoto {
    init(_ m: PagoCapturado, usuario: UUID) {
        self.init(
            id: m.id, usuarioID: usuario, comercioBruto: m.comercioBruto, comercioLimpio: m.comercioLimpio,
            importeCentimos: m.importeCentimos, divisa: m.divisa, tarjeta: m.tarjeta, fecha: m.fecha,
            latitud: m.latitud, longitud: m.longitud, puntuacionEmparejado: m.puntuacionEmparejado,
            estado: m.estadoRaw, actualizadoEn: nil, borradoEn: nil
        )
    }

    func volcar(en m: PagoCapturado) {
        m.comercioBruto = comercioBruto
        m.comercioLimpio = comercioLimpio
        m.importeCentimos = importeCentimos
        m.divisa = divisa.trimmingCharacters(in: .whitespaces)
        m.tarjeta = tarjeta
        m.fecha = fecha
        m.latitud = latitud
        m.longitud = longitud
        m.puntuacionEmparejado = puntuacionEmparejado
        m.estadoRaw = estado
    }
}

public extension ListaRemota {
    init(_ m: Lista, usuario: UUID) {
        self.init(
            id: m.id, usuarioID: usuario, nombre: m.nombre, emoji: m.emoji, tipo: m.tipoRaw,
            orden: m.orden, compartida: m.compartida, enlacePublico: m.enlacePublico?.absoluteString,
            creadoEn: m.fechaCreacion, actualizadoEn: nil, borradoEn: nil
        )
    }

    func volcar(en m: Lista) {
        m.nombre = nombre
        m.emoji = emoji
        m.tipoRaw = tipo
        m.orden = orden
        m.compartida = compartida
        m.enlacePublico = enlacePublico.flatMap(URL.init(string:))
        if let creadoEn { m.fechaCreacion = creadoEn }
    }
}

public extension VisitaRemota {
    init(_ m: Visita, usuario: UUID) {
        self.init(
            id: m.id, usuarioID: usuario, restauranteID: m.restaurante?.id, pagoID: m.pago?.id,
            fecha: m.fecha, estado: m.estadoRaw, estrellas: m.estrellas, resena: m.resena,
            volveria: m.volveriaRaw, importeCentimos: m.importeCentimos, divisa: m.divisa,
            comensales: m.comensales, pagueTodo: m.pagueTodo, ocasion: m.ocasion, origen: m.origenRaw,
            creadaPorIA: m.creadaPorIA, actualizadoEn: nil, borradoEn: nil
        )
    }

    /// Campos propios; `restaurante` y `pago` los pone el motor.
    func volcar(en m: Visita) {
        m.fecha = fecha
        m.estadoRaw = estado
        m.estrellas = estrellas
        m.resena = resena
        m.volveriaRaw = volveria
        m.importeCentimos = importeCentimos
        m.divisa = divisa.trimmingCharacters(in: .whitespaces)
        m.comensales = comensales
        m.pagueTodo = pagueTodo
        m.ocasion = ocasion
        m.origenRaw = origen
        m.creadaPorIA = creadaPorIA
    }
}

public extension PlatoRemoto {
    /// `nil` si el plato no pertenece a ninguna visita (no se puede subir).
    init?(_ m: Plato, usuario: UUID) {
        guard let visita = m.visita else { return nil }
        self.init(
            id: m.id, usuarioID: usuario, visitaID: visita.id, nombre: m.nombre,
            valoracion: m.valoracionRaw, precioCentimos: m.precioCentimos, nota: m.nota,
            orden: m.orden, actualizadoEn: nil, borradoEn: nil
        )
    }

    /// Campos propios; `visita` la pone el motor.
    func volcar(en m: Plato) {
        m.nombre = nombre
        m.valoracionRaw = valoracion
        m.precioCentimos = precioCentimos
        m.nota = nota
        m.orden = orden
    }
}

public extension FotoRemota {
    /// `nil` si la foto no pertenece a ninguna visita. Si aún no se ha subido la imagen,
    /// usa las rutas que tendrá (`FotoRemota.rutas`).
    init?(_ m: Foto, usuario: UUID) {
        guard let visita = m.visita else { return nil }
        let rutas = Self.rutas(usuario: usuario, foto: m.id)
        self.init(
            id: m.id, usuarioID: usuario, visitaID: visita.id, platoID: m.plato?.id,
            ruta: m.rutaRemota ?? rutas.imagen, rutaMiniatura: m.rutaMiniaturaRemota ?? rutas.miniatura,
            fecha: m.fecha, esComida: m.esComida, platoSugerido: m.platoSugerido, orden: m.orden,
            actualizadoEn: nil, borradoEn: nil
        )
    }

    /// Campos propios y rutas; `visita` y `plato` los pone el motor. Las imágenes se bajan aparte.
    func volcar(en m: Foto) {
        if m.rutaMiniaturaRemota != rutaMiniatura { m.miniatura = nil }
        if m.rutaRemota != ruta { m.datos = nil }
        m.rutaRemota = ruta
        m.rutaMiniaturaRemota = rutaMiniatura
        m.fecha = fecha
        m.esComida = esComida
        m.platoSugerido = platoSugerido
        m.orden = orden
    }
}

public extension ListaRestauranteRemota {
    init(lista: Lista, restaurante: Restaurante, usuario: UUID) {
        self.init(
            listaID: lista.id, restauranteID: restaurante.id, usuarioID: usuario,
            creadoEn: nil, actualizadoEn: nil, borradoEn: nil
        )
    }
}

public extension AliasRemoto {
    /// `nil` si el alias no apunta a ningún restaurante.
    init?(_ m: AliasComercio, usuario: UUID) {
        guard let restaurante = m.restaurante else { return nil }
        self.init(
            id: m.id, usuarioID: usuario, comercioLimpio: m.comercioLimpio,
            restauranteID: restaurante.id, vecesConfirmado: m.vecesConfirmado,
            actualizadoEn: nil, borradoEn: nil
        )
    }

    func volcar(en m: AliasComercio) {
        m.comercioLimpio = comercioLimpio
        m.vecesConfirmado = vecesConfirmado
    }
}
