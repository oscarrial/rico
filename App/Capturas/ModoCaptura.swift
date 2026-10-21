#if DEBUG
import Foundation
import SwiftData
import Modelos
import RicoCore

/// Arranque para sacar capturas en la CI (`.github/workflows/capturas.yml`):
/// `-captura <pantalla>` abre la app con datos de ejemplo directamente en esa pantalla.
/// Solo existe en Debug.
enum ModoCaptura {
    enum Pantalla: String {
        case bienvenida, acceso, diario, mapa, listas, resumen, cuenta, premium, ficha, valorar, bandeja, alta
    }

    static let actual: Pantalla? = {
        let argumentos = ProcessInfo.processInfo.arguments
        guard let indice = argumentos.firstIndex(of: "-captura"), indice + 1 < argumentos.count else { return nil }
        return Pantalla(rawValue: argumentos[indice + 1])
    }()

    /// Base en memoria con un diario de ejemplo creíble.
    @MainActor
    static func contenedorDemo() -> ModelContainer {
        let contenedor = try! ContenedorRico.crear(enMemoria: true)
        DatosDemo.cargar(en: contenedor.mainContext)
        return contenedor
    }
}

@MainActor
enum DatosDemo {
    private struct Sitio {
        let nombre: String
        let ciudad: String
        let direccion: String
        let cocina: String
        let lat: Double
        let lon: Double
    }

    private static let sitios: [Sitio] = [
        Sitio(nombre: "Taberna O Grelo", ciudad: "Vigo", direccion: "Rúa Real, 12", cocina: "Gallega", lat: 42.2406, lon: -8.7207),
        Sitio(nombre: "Maruja Limón", ciudad: "Vigo", direccion: "Rúa de Montero Ríos, 4", cocina: "De autor", lat: 42.2387, lon: -8.7231),
        Sitio(nombre: "Casa Marcelo", ciudad: "Santiago", direccion: "Rúa das Hortas, 1", cocina: "Fusión", lat: 42.8812, lon: -8.5458),
        Sitio(nombre: "Pulpería A Garnacha", ciudad: "Vigo", direccion: "Rúa Teófilo Llorente, 7", cocina: "Gallega", lat: 42.2365, lon: -8.7188),
        Sitio(nombre: "La Trattoria di Enzo", ciudad: "Vigo", direccion: "Rúa Ecuador, 30", cocina: "Italiana", lat: 42.2321, lon: -8.7149),
        Sitio(nombre: "Sushi Kaze", ciudad: "Vigo", direccion: "Avenida de García Barbón, 52", cocina: "Japonesa", lat: 42.2368, lon: -8.7140),
        Sitio(nombre: "Bar Ramón", ciudad: "Vigo", direccion: "Praza da Constitución, 3", cocina: "Tapas", lat: 42.2402, lon: -8.7255)
    ]

    /// (sitio, días atrás, estrellas, importe en céntimos, comensales, volvería, platos)
    private static let visitas: [(Int, Int, Double, Int, Int, Volveria?, [(String, ValoracionPlato?)])] = [
        (0, 1, 4.5, 6400, 2, .si, [("Pulpo á feira", .encanto), ("Zamburiñas", .bien), ("Filloas", .encanto)]),
        (1, 3, 5, 11200, 2, .si, [("Vieira con tupinambo", .encanto), ("Merluza de pincho", .encanto)]),
        (4, 6, 3.5, 4200, 2, .quiza, [("Carbonara", .bien), ("Tiramisú", .noRepetiria)]),
        (3, 9, 4, 3600, 3, .si, [("Pulpo", .encanto), ("Pimientos de Padrón", .bien)]),
        (5, 14, 3, 5800, 2, .no, [("Nigiri de salmón", .bien), ("Gyozas", .noRepetiria)]),
        (6, 18, 4, 2200, 2, .si, [("Tortilla", .encanto), ("Croquetas", .bien)]),
        (0, 26, 4.5, 5200, 2, .si, [("Empanada de zamburiñas", .encanto)]),
        (2, 34, 5, 16800, 2, .si, [("Menú degustación", .encanto)]),
        (1, 41, 4.5, 9800, 2, .si, [("Arroz de bogavante", .encanto)]),
        (4, 55, 4, 3900, 2, .quiza, [("Pizza margarita", .bien)]),
        (6, 70, 3.5, 1800, 1, .si, [("Bocadillo de calamares", .bien)])
    ]

    static func cargar(en contexto: ModelContext) {
        let calendario = Calendar.current
        let ahora = calendario.date(bySettingHour: 14, minute: 30, second: 0, of: .now) ?? .now

        let restaurantes = sitios.map { sitio -> Restaurante in
            let restaurante = Restaurante(nombre: sitio.nombre)
            restaurante.ciudad = sitio.ciudad
            restaurante.direccion = sitio.direccion
            restaurante.cocina = sitio.cocina
            restaurante.latitud = sitio.lat
            restaurante.longitud = sitio.lon
            contexto.insert(restaurante)
            return restaurante
        }

        for (sitio, dias, estrellas, centimos, comensales, volveria, platos) in visitas {
            let visita = Visita(fecha: calendario.date(byAdding: .day, value: -dias, to: ahora) ?? ahora)
            contexto.insert(visita)
            visita.restaurante = restaurantes[sitio]
            visita.estrellas = estrellas
            visita.importe = Importe(centimos: centimos, divisa: "EUR")
            visita.comensales = comensales
            visita.volveria = volveria
            visita.estado = .valorada
            for (orden, (nombre, valoracion)) in platos.enumerated() {
                let plato = Plato(nombre: nombre, valoracion: valoracion, orden: orden)
                contexto.insert(plato)
                plato.visita = visita
            }
        }

        // Un pago de Apple Pay esperando a que lo valores.
        let borrador = Visita(fecha: calendario.date(byAdding: .hour, value: -2, to: ahora) ?? ahora, origen: .pago)
        contexto.insert(borrador)
        borrador.restaurante = restaurantes[3]
        borrador.importe = Importe(centimos: 4750, divisa: "EUR")

        // Listas.
        let quieroProbar = try? contexto.listaQuieroProbar()
        let pendiente = Restaurante(nombre: "Néboa")
        pendiente.ciudad = "Vigo"
        pendiente.cocina = "De autor"
        pendiente.latitud = 42.2380
        pendiente.longitud = -8.7175
        contexto.insert(pendiente)
        if let quieroProbar { try? contexto.anadir(pendiente, a: quieroProbar) }
        if let favoritos = try? contexto.crearLista(nombre: "Para ir con amigos", emoji: "🍻", esPremium: true) {
            try? contexto.anadir(restaurantes[6], a: favoritos)
            try? contexto.anadir(restaurantes[3], a: favoritos)
        }
        if let especiales = try? contexto.crearLista(nombre: "Ocasiones especiales", emoji: "🥂", esPremium: true) {
            try? contexto.anadir(restaurantes[2], a: especiales)
            try? contexto.anadir(restaurantes[1], a: especiales)
        }

        try? contexto.save()
    }
}
#endif

#if DEBUG
import SwiftUI
import Captura
import Premium
import Visitas

/// Lleva la raíz a la pantalla pedida con `-captura`.
struct PantallaCapturaModifier: ViewModifier {
    let pantalla: ModoCaptura.Pantalla?
    let restaurante: Restaurante?
    let premium: EstadoPremium
    @Binding var pestana: RaizView.Pestana
    @Binding var bienvenidaVista: Bool
    @Binding var mostrandoCuenta: Bool

    @State private var hoja: ModoCaptura.Pantalla?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let pantalla else { return }
                bienvenidaVista = pantalla != .bienvenida
                switch pantalla {
                case .mapa: pestana = .mapa
                case .listas: pestana = .listas
                case .resumen: pestana = .resumen
                case .cuenta: mostrandoCuenta = true
                case .premium, .ficha, .valorar, .bandeja, .alta: hoja = pantalla
                case .bienvenida, .acceso, .diario: break
                }
            }
            .sheet(item: $hoja) { pantalla in
                switch pantalla {
                case .premium:
                    PaywallView()
                        .environment(premium)
                case .ficha:
                    if let restaurante {
                        NavigationStack { FichaRestauranteView(restaurante: restaurante) }
                    }
                case .valorar:
                    if let restaurante {
                        FichaRapidaView(modelo: FichaRapidaModelo(restaurante: restaurante))
                    }
                case .bandeja:
                    BandejaPendientesView()
                case .alta:
                    AltaManualView()
                default:
                    EmptyView()
                }
            }
    }
}

extension ModoCaptura.Pantalla: Identifiable {
    var id: String { rawValue }
}
#endif
