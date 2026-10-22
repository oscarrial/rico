import SwiftUI
import Captura
import Cuenta
import DesignSystem
import Estadisticas
import Listas
import Mapa
import Modelos
import Premium
import SwiftData
import Visitas

/// Las cuatro pestañas de la app: Diario, Mapa, Listas y Resumen.
struct RaizView: View {
    @State private var pestana: Pestana = .diario
    @State private var premium = EstadoPremium()
    @Environment(EstadoCuenta.self) private var cuenta
    @State private var mostrandoCuenta = false
    @AppStorage("bienvenidaVista") private var bienvenidaVista = false
    #if DEBUG
    @State private var pantallaCaptura = ModoCaptura.actual
    @Query(sort: \Restaurante.nombre) private var restaurantesCaptura: [Restaurante]
    #endif

    enum Pestana: Hashable { case diario, mapa, listas, resumen }

    var body: some View {
        TabView(selection: $pestana) {
            DiarioView(alAbrirCuenta: { mostrandoCuenta = true }) {
                AvisoPendientesView()
            }
            .tabItem { Label { Text("Diario") } icon: { Image(systemName: "book") } }
            .tag(Pestana.diario)

            MapaView()
                .tabItem { Label { Text("Mapa") } icon: { Image(systemName: "map") } }
                .tag(Pestana.mapa)

            ListasView()
                .tabItem { Label { Text("Listas") } icon: { Image(systemName: "bookmark") } }
                .tag(Pestana.listas)

            ResumenView()
                .tabItem { Label { Text("Resumen") } icon: { Image(systemName: "chart.bar") } }
                .tag(Pestana.resumen)
        }
        // La cuenta se abre desde aquí (no desde RicoApp) para que herede el estado de Premium.
        .sheet(isPresented: $mostrandoCuenta) {
            CuentaView {
                NavigationLink {
                    GuiaAtajoView()
                } label: {
                    Label { Text("Pagos con Apple Pay") } icon: { Image(systemName: "creditcard") }
                }
            }
        }
        .permitePedirPremium()
        .environment(premium)
        .environment(\.esPremium, premium.esPremium)
        .environment(\.hojaPremium, HojaPremium { [premium] in
            PaywallView()
                .environment(premium)
        })
        // Comprueba las compras al arrancar y escucha renovaciones y reembolsos.
        .task { await premium.arrancar() }
        .onChange(of: cuenta.sesion?.premiumConcedido ?? false, initial: true) { _, concedido in
            premium.conceder(concedido)
        }
        .fullScreenCover(isPresented: Binding(get: { !bienvenidaVista }, set: { bienvenidaVista = !$0 })) {
            BienvenidaView { bienvenidaVista = true }
        }
        // Al tocar un aviso «¿Qué tal en…?» o un enlace rico://visita/<uuid>.
        .abrirVisitaDesdeAviso()
        #if DEBUG
        .modifier(PantallaCapturaModifier(
            pantalla: pantallaCaptura,
            restaurante: restaurantesCaptura.first { $0.nombre == "Taberna O Grelo" },
            premium: premium,
            pestana: $pestana,
            bienvenidaVista: $bienvenidaVista,
            mostrandoCuenta: $mostrandoCuenta
        ))
        #endif
    }
}
