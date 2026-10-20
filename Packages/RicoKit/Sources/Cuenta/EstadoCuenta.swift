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

    /// Clave donde queda el id de la cuenta cuyo borrado local está pendiente.
    public static let claveBorradoLocalPendiente = "RicoBorradoLocalPendiente"

    public let servicio: (any ServicioCuenta)?
    @ObservationIgnored private let preferencias: UserDefaults
    @ObservationIgnored private var escucha: Task<Void, Never>?

    public init(
        servicio: (any ServicioCuenta)?,
        esperaMaxima: Duration = .seconds(3),
        preferencias: UserDefaults = .standard
    ) {
        self.servicio = servicio
        self.preferencias = preferencias
        guard let servicio else {
            fase = .soloLocal
            return
        }
        fase = .cargando
        escucha = Task { [weak self] in
            for await sesion in servicio.cambiosDeSesion() {
                self?.fase = sesion.map(Fase.conSesion) ?? .sinSesion
                if case .conSesion = self?.fase { self?.errorEnlace = nil }
            }
        }
        // Sin respuesta a tiempo (p. ej. sin red): usa lo guardado en el llavero.
        Task { [weak self] in
            try? await Task.sleep(for: esperaMaxima)
            guard let self, self.fase == .cargando else { return }
            self.fase = servicio.sesionActual.map(Fase.conSesion) ?? .sinSesion
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
    }

    /// Cierra la hoja de «Nueva contraseña» (el usuario ya vio la confirmación).
    public func terminarRecuperacion() {
        pidiendoNuevaContrasena = false
    }

    public func olvidarErrorEnlace() {
        errorEnlace = nil
    }

    public func cerrarSesion() async throws {
        try await requerido().cerrarSesion()
    }

    /// Borra la cuenta en el servidor y después los datos locales; cierra la sesión al final.
    /// Si el borrado local falla, queda anotado para repetirlo al volver a abrir esa cuenta.
    public func borrarCuenta(codigoApple: String?, borrarLocal: () throws -> Void) async throws {
        let servicio = try requerido()
        let usuario = sesion?.id ?? servicio.sesionActual?.id
        try await servicio.borrarCuenta(codigoApple: codigoApple)
        if let usuario {
            preferencias.set(usuario.uuidString, forKey: Self.claveBorradoLocalPendiente)
        }
        try borrarLocal()
        preferencias.removeObject(forKey: Self.claveBorradoLocalPendiente)
        try? await servicio.cerrarSesion()
    }

    /// Si quedó un borrado local a medias para `usuario`, lo termina con `borrarLocal`.
    public func completarBorradoLocalPendiente(de usuario: UUID?, borrarLocal: () throws -> Void) {
        guard let usuario,
              preferencias.string(forKey: Self.claveBorradoLocalPendiente) == usuario.uuidString,
              (try? borrarLocal()) != nil
        else { return }
        preferencias.removeObject(forKey: Self.claveBorradoLocalPendiente)
    }

    private func requerido() throws -> any ServicioCuenta {
        guard let servicio else { throw ErrorCuenta.otro("Sin servidor configurado") }
        return servicio
    }
}
