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

    public func enviarCodigo(a correo: String) async throws {
        try await requerido().enviarCodigo(a: correo)
    }

    public func verificarCodigo(_ codigo: String, correo: String) async throws {
        try await requerido().verificarCodigo(codigo, correo: correo)
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
