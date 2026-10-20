import SwiftUI
import SwiftData
import Cuenta
import DesignSystem
import Modelos
import Visitas

@main
struct RicoApp: App {
    let contenedor: ModelContainer
    @State private var cuenta: EstadoCuenta
    @State private var mostrarInicio = true
    @State private var mostrandoCuenta = false

    init() {
        do {
            contenedor = try ContenedorRico.crear()
        } catch {
            // Sin firma (simulador de CI) no hay App Group: base local de la app.
            print("Rico: sin App Group (\(error)); se usa el almacenamiento de la app.")
            do {
                contenedor = try ContenedorRico.crear(usarGrupo: false)
            } catch {
                fatalError("No se pudo abrir la base de datos: \(error)")
            }
        }

        // Sin Config/Secretos.xcconfig la app funciona solo en local, sin cuenta.
        let servicio = ConfiguracionSupabase.desdeInfoPlist().map {
            ServicioCuentaSupabase(cliente: ClienteRico.crear($0))
        }
        _cuenta = State(initialValue: EstadoCuenta(servicio: servicio))
    }

    var body: some Scene {
        WindowGroup {
            raiz
                .environment(cuenta)
                .tint(.ricoTomate)
                .overlay {
                    // El arranque se mantiene hasta saber si hay sesión.
                    if mostrarInicio || cuenta.fase == .cargando {
                        PantallaInicio(visible: $mostrarInicio)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: cuenta.fase)
                // Enlaces de los correos: confirmar la cuenta o recuperar la contraseña.
                .onOpenURL { url in
                    Task { await cuenta.abrirEnlace(url) }
                }
                .sheet(isPresented: $cuenta.pidiendoNuevaContrasena) {
                    NuevaContrasenaView()
                }
        }
        .modelContainer(contenedor)
    }

    @ViewBuilder
    private var raiz: some View {
        switch cuenta.fase {
        case .conSesion, .soloLocal:
            DiarioView(alAbrirCuenta: { mostrandoCuenta = true })
                .sheet(isPresented: $mostrandoCuenta) {
                    CuentaView()
                }
        case .sinSesion:
            AccesoView()
        case .cargando:
            Color("FondoInicio").ignoresSafeArea()
        }
    }
}
