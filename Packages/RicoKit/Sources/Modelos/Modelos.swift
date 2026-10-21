import Foundation
import SwiftData
import RicoCore

// Reglas de los modelos: propiedades opcionales o con valor por defecto, relaciones
// opcionales y enums guardados como texto. Así se pueden sincronizar con Supabase
// y migrar sin romper datos.

@Model
public final class Restaurante {
    public var id: UUID = UUID()
    public var nombre: String = ""
    public var direccion: String?
    public var ciudad: String?
    public var pais: String?
    public var latitud: Double?
    public var longitud: Double?
    /// Identificador de Apple Maps (`MKMapItem.identifier`).
    public var mapItemID: String?
    public var cocina: String?
    /// 1 a 4 (€ a €€€€).
    public var rangoPrecio: Int?
    public var telefono: String?
    public var web: URL?
    public var silenciado: Bool = false
    public var fechaCreacion: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Visita.restaurante)
    public var visitas: [Visita]? = []

    @Relationship(inverse: \Lista.restaurantes)
    public var listas: [Lista]? = []

    @Relationship(deleteRule: .cascade, inverse: \AliasComercio.restaurante)
    public var alias: [AliasComercio]? = []

    public init(nombre: String) {
        self.nombre = nombre
    }
}

@Model
public final class Visita {
    public var id: UUID = UUID()
    public var fecha: Date = Date()
    public var estadoRaw: String = EstadoVisita.borrador.rawValue
    /// 0,5 a 5 en medias estrellas; `nil` mientras no se valora.
    public var estrellas: Double?
    public var resena: String?
    public var volveriaRaw: String?
    public var importeCentimos: Int?
    public var divisa: String = "EUR"
    public var comensales: Int = 1
    public var pagueTodo: Bool = true
    public var ocasion: String?
    public var origenRaw: String = OrigenVisita.manual.rawValue
    public var creadaPorIA: Bool = false

    public var restaurante: Restaurante?

    @Relationship(deleteRule: .cascade, inverse: \Plato.visita)
    public var platos: [Plato]? = []

    @Relationship(deleteRule: .cascade, inverse: \Foto.visita)
    public var fotos: [Foto]? = []

    @Relationship(deleteRule: .nullify, inverse: \PagoCapturado.visita)
    public var pago: PagoCapturado?

    public init(fecha: Date = .now, origen: OrigenVisita = .manual) {
        self.fecha = fecha
        self.origenRaw = origen.rawValue
    }

    public var estado: EstadoVisita {
        get { EstadoVisita(rawValue: estadoRaw) ?? .borrador }
        set { estadoRaw = newValue.rawValue }
    }

    public var origen: OrigenVisita {
        get { OrigenVisita(rawValue: origenRaw) ?? .manual }
        set { origenRaw = newValue.rawValue }
    }

    public var volveria: Volveria? {
        get { volveriaRaw.flatMap(Volveria.init(rawValue:)) }
        set { volveriaRaw = newValue?.rawValue }
    }

    public var importe: Importe? {
        get { importeCentimos.map { Importe(centimos: $0, divisa: divisa) } }
        set {
            importeCentimos = newValue?.centimos
            if let divisa = newValue?.divisa { self.divisa = divisa }
        }
    }

    public var importePorPersona: Importe? {
        importe?.porPersona(comensales: comensales, pagueTodo: pagueTodo)
    }

    /// Fotos en el orden en que se añadieron.
    public var fotosOrdenadas: [Foto] {
        (fotos ?? []).sorted { $0.orden < $1.orden }
    }

    public var platosOrdenados: [Plato] {
        (platos ?? []).sorted { $0.orden < $1.orden }
    }
}

@Model
public final class Plato {
    public var id: UUID = UUID()
    public var nombre: String = ""
    public var valoracionRaw: String?
    public var precioCentimos: Int?
    public var nota: String?
    public var orden: Int = 0

    public var visita: Visita?

    @Relationship(deleteRule: .nullify, inverse: \Foto.plato)
    public var fotos: [Foto]? = []

    public init(nombre: String, valoracion: ValoracionPlato? = nil, orden: Int = 0) {
        self.nombre = nombre
        self.valoracionRaw = valoracion?.rawValue
        self.orden = orden
    }

    public var valoracion: ValoracionPlato? {
        get { valoracionRaw.flatMap(ValoracionPlato.init(rawValue:)) }
        set { valoracionRaw = newValue?.rawValue }
    }
}

@Model
public final class Foto {
    public var id: UUID = UUID()
    /// Imagen completa, en almacenamiento externo de SwiftData. Con la sincronización se sube al bucket privado `fotos` de Supabase.
    @Attribute(.externalStorage) public var datos: Data?
    @Attribute(.externalStorage) public var miniatura: Data?
    public var fecha: Date = Date()
    public var esComida: Bool = false
    public var platoSugerido: String?
    /// Identificador local de la foto en el carrete, para no sugerirla dos veces.
    public var identificadorCarrete: String?
    public var orden: Int = 0
    /// Ruta de la imagen en el bucket `fotos` del servidor (`<usuario>/<id>.jpg`); `nil` si aún no se ha subido.
    public var rutaRemota: String?
    /// Ruta de la miniatura en el bucket `fotos` (`<usuario>/<id>-mini.jpg`).
    public var rutaMiniaturaRemota: String?

    public var visita: Visita?
    public var plato: Plato?

    public init(datos: Data?, miniatura: Data?, fecha: Date = .now, orden: Int = 0) {
        self.datos = datos
        self.miniatura = miniatura
        self.fecha = fecha
        self.orden = orden
    }
}

@Model
public final class Lista {
    public var id: UUID = UUID()
    public var nombre: String = ""
    public var emoji: String?
    public var tipoRaw: String = TipoLista.propia.rawValue
    public var orden: Int = 0
    public var compartida: Bool = false
    public var enlacePublico: URL?
    public var fechaCreacion: Date = Date()

    public var restaurantes: [Restaurante]? = []

    public init(nombre: String, tipo: TipoLista = .propia) {
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
    }

    public var tipo: TipoLista {
        get { TipoLista(rawValue: tipoRaw) ?? .propia }
        set { tipoRaw = newValue.rawValue }
    }
}

@Model
public final class PagoCapturado {
    public var id: UUID = UUID()
    public var comercioBruto: String = ""
    public var comercioLimpio: String = ""
    public var importeCentimos: Int = 0
    public var divisa: String = "EUR"
    public var tarjeta: String?
    public var fecha: Date = Date()
    public var latitud: Double?
    public var longitud: Double?
    public var puntuacionEmparejado: Double?
    public var estadoRaw: String = EstadoPago.pendiente.rawValue

    public var visita: Visita?

    public init(comercioBruto: String, importe: Importe, fecha: Date = .now, tarjeta: String? = nil) {
        self.comercioBruto = comercioBruto
        self.comercioLimpio = LimpiadorComercio.limpiar(comercioBruto)
        self.importeCentimos = importe.centimos
        self.divisa = importe.divisa
        self.fecha = fecha
        self.tarjeta = tarjeta
    }

    public var estado: EstadoPago {
        get { EstadoPago(rawValue: estadoRaw) ?? .pendiente }
        set { estadoRaw = newValue.rawValue }
    }

    public var importe: Importe { Importe(centimos: importeCentimos, divisa: divisa) }
}

/// «Nombre del pago → restaurante», aprendido cuando el usuario corrige el emparejado.
@Model
public final class AliasComercio {
    public var id: UUID = UUID()
    public var comercioLimpio: String = ""
    public var vecesConfirmado: Int = 1

    public var restaurante: Restaurante?

    public init(comercioLimpio: String, restaurante: Restaurante) {
        self.comercioLimpio = comercioLimpio
        self.restaurante = restaurante
    }
}
