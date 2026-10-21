import SwiftUI
import SwiftData
import Cuenta
import DesignSystem
import Modelos
import Visitas

@main
struct RicoApp: App {
    @State private var contenedor: ModelContainer
    @State private var usuarioDelContenedor: UUID?
    @State private var cuenta: EstadoCuenta
    @State private var mostrarInicio = true
    @State private var mostrandoCuenta = false

    init() {
        // Contenedor provisional (sin cuenta): no se muestra hasta conocer la fase.
        _contenedor = State(initialValue: Self.abrirContenedor(usuario: nil))

        // Sin Config/Secretos.xcconfig la app funciona solo en local, sin cuenta.
        let servicio = ConfiguracionSupabase.desdeInfoPlist().map {
            ServicioCuentaSupabase(cliente: ClienteRico.crear($0))
        }
        _cuenta = State(initialValue: EstadoCuenta(servicio: servicio))
    }

    /// Abre la base local de esa cuenta (o la del modo sin cuenta si `usuario` es `nil`).
    static func abrirContenedor(usuario: UUID?) -> ModelContainer {
        do {
            return try ContenedorRico.crear(usuario: usuario)
        } catch {
            // Sin firma (simulador de CI) no hay App Group: base local de la app.
            Registro.datos.notice("Sin App Group (\(String(describing: error), privacy: .public)); se usa el almacenamiento de la app.")
            do {
                return try ContenedorRico.crear(usuario: usuario, usarGrupo: false)
            } catch {
                fatalError("No se pudo abrir la base de datos: \(error)")
            }
        }
    }

    /// Cuenta cuya base debe estar abierta. En `.cargando` y `.sinSesion` no cambia.
    private var usuarioActivo: UUID? {
        switch cuenta.fase {
        case .conSesion(let sesion): sesion.id
        case .soloLocal: nil
        case .cargando, .sinSesion: usuarioDelContenedor
        }
    }

    var body: some Scene {
        WindowGroup {
            raiz
                .id(usuarioDelContenedor)
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
                .onChange(of: usuarioActivo, initial: true) { _, nuevo in
                    guard nuevo != usuarioDelContenedor else { return }
                    let abierto = Self.abrirContenedor(usuario: nuevo)
                    contenedor = abierto
                    usuarioDelContenedor = nuevo
                    // Si el borrado local de esta cuenta quedó a medias, se termina ahora.
                    cuenta.completarBorradoLocalPendiente(de: nuevo) {
                        try ContenedorRico.borrarTodo(en: abierto.mainContext)
                    }
                }
        }
        .modelContainer(contenedor)
    }

    @ViewBuilder
    private var raiz: some View {
        switch cuenta.fase {
        case .conSesion, .soloLocal:
            RaizView(alAbrirCuenta: { mostrandoCuenta = true })
                .sheet(isPresented: $mostrandoCuenta) {
                    CuentaView()
                }
                .sheet(isPresented: $cuenta.pidiendoNuevaContrasena) {
                    NuevaContrasenaView()
                }
                .alert(
                    Text("No se pudo abrir el enlace", bundle: .main),
                    isPresented: Binding(
                        get: { cuenta.errorEnlace != nil },
                        set: { if !$0 { cuenta.olvidarErrorEnlace() } }
                    )
                ) {
                    Button("Vale") {}
                } message: {
                    Text("El enlace no es válido o ha caducado. Pide otro.", bundle: .main)
                }
        case .sinSesion:
            AccesoView()
        case .cargando:
            Color("FondoInicio").ignoresSafeArea()
        }
    }
}
