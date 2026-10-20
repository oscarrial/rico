import Foundation
import SwiftData
import Testing
import Cuenta
import Modelos
import Visitas
import RicoCore

/// Servicio de cuentas falso: usuarios en memoria y cambios de sesión por un flujo.
@MainActor
final class ServicioCuentaFalso: ServicioCuenta {
    var sesionActual: SesionUsuario?
    var usuarios: [String: String] = [:]
    var sinConfirmar: Set<String> = []
    var pedirConfirmacion = true
    var recuperacionesEnviadas: [String] = []
    var borrada = false
    private let flujo: AsyncStream<SesionUsuario?>
    private let continuacion: AsyncStream<SesionUsuario?>.Continuation

    init(sesionInicial: SesionUsuario? = nil) {
        sesionActual = sesionInicial
        let par = AsyncStream.makeStream(of: SesionUsuario?.self)
        flujo = par.stream
        continuacion = par.continuation
        continuacion.yield(sesionInicial)
    }

    func cambiosDeSesion() -> AsyncStream<SesionUsuario?> { flujo }

    func iniciarConApple(tokenIdentidad: String, nonce: String) async throws {
        cambiar(a: SesionUsuario(id: UUID(), correo: nil))
    }

    func registrar(correo: String, contrasena: String) async throws -> ResultadoRegistro {
        let correo = ValidadorCorreo.normalizar(correo)
        guard ValidadorCorreo.esValido(correo) else { throw ErrorCuenta.correoNoValido }
        guard ReglasContrasena.esValida(contrasena) else { throw ErrorCuenta.contrasenaDebil }
        guard usuarios[correo] == nil else { throw ErrorCuenta.correoYaRegistrado }
        usuarios[correo] = contrasena
        if pedirConfirmacion {
            sinConfirmar.insert(correo)
            return .confirmaTuCorreo
        }
        cambiar(a: SesionUsuario(id: UUID(), correo: correo))
        return .sesionIniciada
    }

    func iniciarSesion(correo: String, contrasena: String) async throws {
        let correo = ValidadorCorreo.normalizar(correo)
        guard usuarios[correo] == contrasena else { throw ErrorCuenta.credencialesIncorrectas }
        guard !sinConfirmar.contains(correo) else { throw ErrorCuenta.correoSinConfirmar }
        cambiar(a: SesionUsuario(id: UUID(), correo: correo))
    }

    func enviarRecuperacion(a correo: String) async throws {
        recuperacionesEnviadas.append(ValidadorCorreo.normalizar(correo))
    }

    func gestionarEnlace(_ url: URL) async throws -> EnlaceCuenta {
        guard let tipo = EnlaceCuenta(url: url) else { throw ErrorCuenta.enlaceNoValido }
        let correo = url.query?.replacingOccurrences(of: "correo=", with: "") ?? ""
        sinConfirmar.remove(correo)
        cambiar(a: SesionUsuario(id: UUID(), correo: correo))
        return tipo
    }

    func cambiarContrasena(_ nueva: String) async throws {
        guard ReglasContrasena.esValida(nueva) else { throw ErrorCuenta.contrasenaDebil }
        if let correo = sesionActual?.correo { usuarios[correo] = nueva }
    }

    func cerrarSesion() async throws {
        cambiar(a: nil)
    }

    func borrarCuenta() async throws {
        borrada = true
        cambiar(a: nil)
    }

    private func cambiar(a sesion: SesionUsuario?) {
        sesionActual = sesion
        continuacion.yield(sesion)
    }
}

/// Espera a que se cumpla una condición (la sesión llega por un flujo asíncrono).
@MainActor
func esperar(hasta condicion: () -> Bool, segundos: Double = 1) async -> Bool {
    let limite = Date.now.addingTimeInterval(segundos)
    while !condicion() {
        if Date.now > limite { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

@MainActor
@Suite("Cuenta")
struct CuentaTests {
    @Test func sinServidorConfiguradoFuncionaEnLocal() {
        let estado = EstadoCuenta(servicio: nil)
        #expect(estado.fase == .soloLocal)
        #expect(estado.sesion == nil)
    }

    @Test func empiezaCargandoYPasaASinSesion() async {
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso())
        #expect(estado.fase == .cargando)
        #expect(await esperar { estado.fase == .sinSesion })
    }

    @Test func recuperaLaSesionGuardada() async {
        let sesion = SesionUsuario(id: UUID(), correo: "ana@ejemplo.com")
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso(sesionInicial: sesion))
        #expect(await esperar { estado.fase == .conSesion(sesion) })
    }

    @Test func crearCuentaConfirmarYEntrar() async throws {
        let servicio = ServicioCuentaFalso()
        let estado = EstadoCuenta(servicio: servicio)
        #expect(try await estado.registrar(correo: " Ana@Ejemplo.com ", contrasena: "pulpo2026") == .confirmaTuCorreo)

        // Sin abrir el enlace no se puede entrar.
        await #expect(throws: ErrorCuenta.correoSinConfirmar) {
            try await estado.iniciarSesion(correo: "ana@ejemplo.com", contrasena: "pulpo2026")
        }

        // El enlace del correo abre la sesión.
        await estado.abrirEnlace(URL(string: "rico://auth/confirmar?correo=ana@ejemplo.com")!)
        #expect(await esperar { estado.sesion?.correo == "ana@ejemplo.com" })
        #expect(!estado.pidiendoNuevaContrasena)

        try await estado.cerrarSesion()
        #expect(await esperar { estado.necesitaAcceso })
        try await estado.iniciarSesion(correo: "ana@ejemplo.com", contrasena: "pulpo2026")
        #expect(await esperar { estado.sesion != nil })
    }

    @Test func contrasenaIncorrecta() async throws {
        let servicio = ServicioCuentaFalso()
        servicio.pedirConfirmacion = false
        let estado = EstadoCuenta(servicio: servicio)
        _ = try await estado.registrar(correo: "ana@ejemplo.com", contrasena: "pulpo2026")
        try await estado.cerrarSesion()
        await #expect(throws: ErrorCuenta.credencialesIncorrectas) {
            try await estado.iniciarSesion(correo: "ana@ejemplo.com", contrasena: "otra2026")
        }
    }

    @Test func noSeRepiteElCorreoNiSeAceptanContrasenasDebiles() async throws {
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso())
        await #expect(throws: ErrorCuenta.contrasenaDebil) {
            _ = try await estado.registrar(correo: "ana@ejemplo.com", contrasena: "corta1")
        }
        _ = try await estado.registrar(correo: "ana@ejemplo.com", contrasena: "pulpo2026")
        await #expect(throws: ErrorCuenta.correoYaRegistrado) {
            _ = try await estado.registrar(correo: "ana@ejemplo.com", contrasena: "pulpo2026")
        }
    }

    @Test func enlaceDeRecuperacionPideContrasenaNueva() async throws {
        let servicio = ServicioCuentaFalso()
        let estado = EstadoCuenta(servicio: servicio)
        try await estado.enviarRecuperacion(a: "ana@ejemplo.com")
        #expect(servicio.recuperacionesEnviadas == ["ana@ejemplo.com"])

        await estado.abrirEnlace(URL(string: "rico://auth/recuperar?correo=ana@ejemplo.com")!)
        #expect(estado.pidiendoNuevaContrasena)
        try await estado.cambiarContrasena("nueva2026")
        #expect(!estado.pidiendoNuevaContrasena)
        #expect(servicio.usuarios["ana@ejemplo.com"] == "nueva2026")
    }

    @Test func otrosEnlacesSeIgnoran() async {
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso())
        await estado.abrirEnlace(URL(string: "https://rico.app/l/123")!)
        await estado.abrirEnlace(URL(string: "rico://otra/cosa")!)
        #expect(estado.errorEnlace == nil)
        #expect(!estado.pidiendoNuevaContrasena)
    }

    @Test func reglasDeContrasena() {
        #expect(!ReglasContrasena.esValida("pulpo"))
        #expect(!ReglasContrasena.esValida("pulpoalafeira"))
        #expect(!ReglasContrasena.esValida("12345678"))
        #expect(ReglasContrasena.esValida("pulpo2026"))
        #expect(ReglasContrasena.cumple(.longitud, "12345678"))
        #expect(!ReglasContrasena.cumple(.letra, "12345678"))
    }

    @Test func enlacesDeCuenta() {
        #expect(EnlaceCuenta(url: EnlaceCuenta.urlConfirmacion) == .confirmacion)
        #expect(EnlaceCuenta(url: EnlaceCuenta.urlRecuperacion) == .recuperacion)
        #expect(EnlaceCuenta(url: URL(string: "rico://auth/otra")!) == nil)
    }

    @Test func cerrarSesionVuelveAlAcceso() async throws {
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso())
        try await estado.iniciarConApple(tokenIdentidad: "token", nonce: "nonce")
        #expect(await esperar { estado.sesion != nil })
        try await estado.cerrarSesion()
        #expect(await esperar { estado.necesitaAcceso })
    }

    @Test(arguments: ["ana@ejemplo.com", "a.b+rico@sub.dominio.es"])
    func correosValidos(correo: String) {
        #expect(ValidadorCorreo.esValido(correo))
    }

    @Test(arguments: ["", "ana", "ana@", "@ejemplo.com", "ana@ejemplo", "ana @ejemplo.com", "ana@ejemplo.c"])
    func correosNoValidos(correo: String) {
        #expect(!ValidadorCorreo.esValido(correo))
    }

    @Test func nonceAleatorioYHash() {
        let nonce = Nonce.aleatorio()
        #expect(nonce.count == 32)
        #expect(nonce != Nonce.aleatorio())
        #expect(Nonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func borrarTodoVaciaLaBaseLocal() throws {
        let contenedor = try ContenedorRico.crear(enMemoria: true)
        let contexto = contenedor.mainContext
        let modelo = FichaRapidaModelo(lugar: LugarEncontrado(nombre: "Casa Pepe", latitud: 42.2, longitud: -8.7))
        modelo.estrellas = 4
        modelo.platos = [BorradorPlato(nombre: "Croquetas")]
        try modelo.guardar(en: contexto)

        try ContenedorRico.borrarTodo(en: contexto)

        #expect(try contexto.fetchCount(FetchDescriptor<Visita>()) == 0)
        #expect(try contexto.fetchCount(FetchDescriptor<Restaurante>()) == 0)
        #expect(try contexto.fetchCount(FetchDescriptor<Plato>()) == 0)
    }
}
