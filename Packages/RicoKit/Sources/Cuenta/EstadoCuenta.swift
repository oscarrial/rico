import Foundation
import Observation

/// Estado de la sesión que observa toda la app.
@MainActor
@Observable
public final class EstadoCuenta {
    public enum Fase: Equatable {
        /// Aún no se sabe si hay sesión (se lee del llavero).
        case cargando
        case sinSesion
        case conSesion(SesionUsuario)
        /// Supabase sin configurar: la app funciona solo en local, sin cuenta.
        case soloLocal
    }

    public private(set) var fase: Fase
    /// Se ha abierto un enlace de «¿Has olvidado tu contraseña?»: hay que pedir la nueva.
    public var pidiendoNuevaContrasena = false
    /// Error al abrir un enlace del correo, para mostrarlo.
    public var errorEnlace: ErrorCuenta?

    public let servicio: (any ServicioCuenta)?
    @ObservationIgnored private var escucha: Task<Void, Never>?

    public init(servicio: (any ServicioCuenta)?) {
        self.servicio = servicio
        guard let servicio else {
            fase = .soloLocal
            return
        }
        fase = .cargando
        escucha = Task { [weak self] in
            for await sesion in servicio.cambiosDeSesion() {
                self?.fase = sesion.map(Fase.conSesion) ?? .sinSesion
            }
        }
    }

    public var sesion: SesionUsuario? {
        if case let .conSesion(sesion) = fase { return sesion }
        return nil
    }

    public var necesitaAcceso: Bool { fase == .sinSesion }

    // MARK: Acciones

    public func iniciarConApple(tokenIdentidad: String, nonce: String) async throws {
        try await requerido().iniciarConApple(tokenIdentidad: tokenIdentidad, nonce: nonce)
    }

    public func registrar(correo: String, contrasena: String) async throws -> ResultadoRegistro {
        try await requerido().registrar(correo: correo, contrasena: contrasena)
    }

    public func iniciarSesion(correo: String, contrasena: String) async throws {
        try await requerido().iniciarSesion(correo: correo, contrasena: contrasena)
    }

    public func enviarRecuperacion(a correo: String) async throws {
        try await requerido().enviarRecuperacion(a: correo)
    }

    /// Para `.onOpenURL`: ignora enlaces que no son de cuenta.
    public func abrirEnlace(_ url: URL) async {
        guard EnlaceCuenta(url: url) != nil, let servicio else { return }
        do {
            let tipo = try await servicio.gestionarEnlace(url)
            errorEnlace = nil
            pidiendoNuevaContrasena = tipo == .recuperacion
        } catch let error as ErrorCuenta {
            errorEnlace = error
        } catch {
            errorEnlace = .enlaceNoValido
        }
    }

    public func cambiarContrasena(_ nueva: String) async throws {
        try await requerido().cambiarContrasena(nueva)
        pidiendoNuevaContrasena = false
    }

    public func cerrarSesion() async throws {
        try await requerido().cerrarSesion()
    }

    public func borrarCuenta() async throws {
        try await requerido().borrarCuenta()
    }

    private func requerido() throws -> any ServicioCuenta {
        guard let servicio else { throw ErrorCuenta.otro("Sin servidor configurado") }
        return servicio
    }
}
