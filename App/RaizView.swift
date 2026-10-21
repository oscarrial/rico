import SwiftUI
import Captura
import DesignSystem
import Estadisticas
import Listas
import Mapa
import Premium
import Visitas

/// Las cuatro pestañas de la app: Diario, Mapa, Listas y Resumen.
struct RaizView: View {
    let alAbrirCuenta: () -> Void

    @State private var pestana: Pestana = .diario
    @State private var premium = EstadoPremium()
    @State private var mostrandoPremium = false
    @AppStorage("bienvenidaVista") private var bienvenidaVista = false

    enum Pestana: Hashable { case diario, mapa, listas, resumen }

    var body: some View {
        TabView(selection: $pestana) {
            DiarioView(alAbrirCuenta: alAbrirCuenta) {
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
        .environment(premium)
        .environment(\.esPremium, premium.esPremium)
        .environment(\.pedirPremium, AccionPremium { mostrandoPremium = true })
        .sheet(isPresented: $mostrandoPremium) {
            PaywallView()
                .environment(premium)
        }
        .fullScreenCover(isPresented: Binding(get: { !bienvenidaVista }, set: { bienvenidaVista = !$0 })) {
            BienvenidaView { bienvenidaVista = true }
        }
    }
}
