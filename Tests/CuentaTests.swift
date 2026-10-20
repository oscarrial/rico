import Foundation
import SwiftData
import Testing
import Cuenta
import Modelos
import Visitas
import RicoCore

/// Servicio de cuentas falso: guarda la sesión en memoria y emite los cambios.
@MainActor
final class ServicioCuentaFalso: ServicioCuenta {
    var sesionActual: SesionUsuario?
    var codigoValido = "123456"
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

    func enviarCodigo(a correo: String) async throws {
        guard ValidadorCorreo.esValido(correo) else { throw ErrorCuenta.correoNoValido }
    }

    func verificarCodigo(_ codigo: String, correo: String) async throws {
        guard codigo == codigoValido else { throw ErrorCuenta.codigoIncorrecto }
        cambiar(a: SesionUsuario(id: UUID(), correo: correo))
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

    @Test func entrarConCodigoDeCorreo() async throws {
        let estado = EstadoCuenta(servicio: ServicioCuentaFalso())
        try await estado.enviarCodigo(a: "ana@ejemplo.com")
        await #expect(throws: ErrorCuenta.codigoIncorrecto) {
            try await estado.verificarCodigo("000000", correo: "ana@ejemplo.com")
        }
        try await estado.verificarCodigo("123456", correo: "ana@ejemplo.com")
        #expect(await esperar { estado.sesion?.correo == "ana@ejemplo.com" })
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
