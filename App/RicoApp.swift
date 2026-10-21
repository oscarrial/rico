import SwiftUI
import SwiftData
import Captura
import Cuenta
import DesignSystem
import Modelos
import Sincronizacion
import Visitas

@main
struct RicoApp: App {
    @State private var contenedor: ModelContainer
    @State private var usuarioDelContenedor: UUID?
    @State private var cuenta: EstadoCuenta
    @State private var mostrarInicio = true
    /// Sube y baja los datos de la cuenta con sesión (no existe en modo solo local).
    @State private var sincronizador: Sincronizador?
    @Environment(\.scenePhase) private var fasePantalla
    private let servicioSincronizacion: (any ServicioSincronizacion)?

    init() {
        #if DEBUG
        if ModoCaptura.actual != nil {
            _contenedor = State(initialValue: ModoCaptura.contenedorDemo())
            _cuenta = State(initialValue: EstadoCuenta(servicio: nil))
            _mostrarInicio = State(initialValue: false)
            servicioSincronizacion = nil
            return
        }
        #endif
        // Contenedor provisional (sin cuenta): no se muestra hasta conocer la fase.
        _contenedor = State(initialValue: Self.abrirContenedor(usuario: nil))

        // Sin Config/Secretos.xcconfig la app funciona solo en local, sin cuenta.
        let servicio = ConfiguracionSupabase.desdeInfoPlist().map {
            ServicioCuentaSupabase(cliente: ClienteRico.crear($0))
        }
        _cuenta = State(initialValue: EstadoCuenta(servicio: servicio))
        servicioSincronizacion = servicio.map { ServicioSincronizacionSupabase(cliente: $0.cliente) }

        // Avisos «¿Qué tal en…?»: el delegado tiene que estar antes de terminar el arranque
        // para recibir el toque que abrió la app.
        DelegadoNotificaciones.activar()

        // «¿Has comido en…?» por ubicación: iOS puede abrir la app en segundo plano para
        // entregar una visita, así que el detector tiene que estar listo desde el arranque.
        DetectorEstancias.compartido.contexto = {
            AlmacenApp.contenedor(usuario: AlmacenApp.usuarioGuardado).mainContext
        }
        DetectorEstancias.compartido.arrancarSiProcede()
    }

    /// Abre la base local de esa cuenta (o la del modo sin cuenta si `usuario` es `nil`).
    /// La comparte con la acción de Atajos «Registrar pago» (ver `AlmacenApp`).
    static func abrirContenedor(usuario: UUID?) -> ModelContainer {
        AlmacenApp.contenedor(usuario: usuario)
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
                .environment(sincronizador)
                .tint(.ricoTomate)
                .overlay {
                    // El arranque se mantiene hasta saber si hay sesión.
                    if mostrarInicio || cuenta.fase == .cargando {
                        PantallaInicio(visible: $mostrarInicio)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: cuenta.fase)
                // rico://visita/<uuid> abre la ficha de esa visita; el resto son enlaces de los
                // correos (confirmar la cuenta o recuperar la contraseña).
                .onOpenURL { url in
                    if AperturaVisita.compartida.abrir(url) { return }
                    Task { await cuenta.abrirEnlace(url) }
                }
                // La acción de Atajos guarda los pagos en la base de la última cuenta abierta.
                .onChange(of: cuenta.fase, initial: true) { _, fase in
                    switch fase {
                    case .conSesion(let sesion): AlmacenApp.usuarioGuardado = sesion.id
                    case .soloLocal: AlmacenApp.usuarioGuardado = nil
                    case .cargando, .sinSesion: break
                    }
                }
                .onChange(of: usuarioActivo, initial: true) { _, nuevo in
                    #if DEBUG
                    if ModoCaptura.actual != nil { return }
                    #endif
                    guard nuevo != usuarioDelContenedor else { return }
                    let abierto = Self.abrirContenedor(usuario: nuevo)
                    contenedor = abierto
                    usuarioDelContenedor = nuevo
                    // Si el borrado local de esta cuenta quedó a medias, se termina ahora.
                    cuenta.completarBorradoLocalPendiente(de: nuevo) {
                        try ContenedorRico.borrarTodo(en: abierto.mainContext)
                    }
                    actualizarSincronizador(usuarioDelContenedor: nuevo, contenedor: abierto)
                }
                .onChange(of: cuenta.sesion?.id) {
                    actualizarSincronizador(usuarioDelContenedor: usuarioDelContenedor, contenedor: contenedor)
                }
                .onChange(of: fasePantalla) { _, fase in
                    if fase == .active { sincronizador?.programar(tras: .zero) }
                }
        }
        .modelContainer(contenedor)
    }

    /// Sincroniza la base abierta solo si es la de la cuenta con sesión. Al cambiar de usuario
    /// o cerrar sesión, para el anterior.
    private func actualizarSincronizador(usuarioDelContenedor: UUID?, contenedor: ModelContainer) {
        let usuario = cuenta.sesion?.id
        let deseado = usuario != nil && usuario == usuarioDelContenedor ? usuario : nil
        guard deseado != sincronizador?.usuario else { return }
        sincronizador?.parar()
        sincronizador = nil
        guard let deseado, let servicioSincronizacion else { return }
        let nuevo = Sincronizador(contexto: contenedor.mainContext, servicio: servicioSincronizacion, usuario: deseado)
        nuevo.arrancar()
        sincronizador = nuevo
    }

    @ViewBuilder
    private var raiz: some View {
        #if DEBUG
        if ModoCaptura.actual == .acceso {
            AccesoView()
        } else {
            raizNormal
        }
        #else
        raizNormal
        #endif
    }

    @ViewBuilder
    private var raizNormal: some View {
        switch cuenta.fase {
        case .conSesion, .soloLocal:
            RaizView()
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
