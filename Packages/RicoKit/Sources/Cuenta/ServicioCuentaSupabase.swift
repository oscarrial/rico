import Foundation
import Supabase

/// Datos del proyecto de Supabase, leídos del Info.plist (vienen de Config/Secretos.xcconfig).
public struct ConfiguracionSupabase: Sendable, Equatable {
    public let url: URL
    public let clavePublica: String

    public init(url: URL, clavePublica: String) {
        self.url = url
        self.clavePublica = clavePublica
    }

    /// `nil` si no está configurado: la app funciona entonces solo en local.
    public static func desdeInfoPlist(_ bundle: Bundle = .main) -> ConfiguracionSupabase? {
        guard let host = (bundle.object(forInfoDictionaryKey: "RicoSupabaseHost") as? String)?.trimmingCharacters(in: .whitespaces),
              let clave = (bundle.object(forInfoDictionaryKey: "RicoSupabaseClave") as? String)?.trimmingCharacters(in: .whitespaces),
              !host.isEmpty, !clave.isEmpty, !host.hasPrefix("$("),
              let url = URL(string: "https://\(host)")
        else { return nil }
        return ConfiguracionSupabase(url: url, clavePublica: clave)
    }
}

/// Cliente de Supabase compartido por las cuentas y la sincronización.
public enum ClienteRico {
    public static func crear(_ configuracion: ConfiguracionSupabase) -> SupabaseClient {
        SupabaseClient(supabaseURL: configuracion.url, supabaseKey: configuracion.clavePublica)
    }
}

@MainActor
public final class ServicioCuentaSupabase: ServicioCuenta {
    public let cliente: SupabaseClient
    static let bucketFotos = "fotos"

    public init(cliente: SupabaseClient) {
        self.cliente = cliente
    }

    public var sesionActual: SesionUsuario? {
        cliente.auth.currentSession.map(Self.sesion)
    }

    public func cambiosDeSesion() -> AsyncStream<SesionUsuario?> {
        let auth = cliente.auth
        return AsyncStream { continuacion in
            let tarea = Task {
                for await cambio in auth.authStateChanges {
                    continuacion.yield(cambio.session.map(Self.sesion))
                }
                continuacion.finish()
            }
            continuacion.onTermination = { _ in tarea.cancel() }
        }
    }

    public func iniciarConApple(tokenIdentidad: String, nonce: String) async throws {
        try await traducirErrores {
            _ = try await cliente.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: tokenIdentidad, nonce: nonce)
            )
        }
    }

    public func registrar(correo: String, contrasena: String) async throws -> ResultadoRegistro {
        let correo = try Self.correoValido(correo)
        guard ReglasContrasena.esValida(contrasena) else { throw ErrorCuenta.contrasenaDebil }
        var resultado = ResultadoRegistro.confirmaTuCorreo
        try await traducirErrores {
            let respuesta = try await cliente.auth.signUp(
                email: correo,
                password: contrasena,
                redirectTo: EnlaceCuenta.urlConfirmacion
            )
            if case .session = respuesta {
                resultado = .sesionIniciada
            }
        }
        return resultado
    }

    public func iniciarSesion(correo: String, contrasena: String) async throws {
        let correo = try Self.correoValido(correo)
        try await traducirErrores {
            _ = try await cliente.auth.signIn(email: correo, password: contrasena)
        }
    }

    public func enviarRecuperacion(a correo: String) async throws {
        let correo = try Self.correoValido(correo)
        try await traducirErrores {
            try await cliente.auth.resetPasswordForEmail(correo, redirectTo: EnlaceCuenta.urlRecuperacion)
        }
    }

    public func gestionarEnlace(_ url: URL) async throws -> EnlaceCuenta {
        guard let tipo = EnlaceCuenta(url: url) else { throw ErrorCuenta.enlaceNoValido }
        do {
            _ = try await cliente.auth.session(from: url)
        } catch let error as URLError {
            throw Self.traducir(error)
        } catch {
            throw ErrorCuenta.enlaceNoValido
        }
        return tipo
    }

    public func cambiarContrasena(_ nueva: String) async throws {
        guard ReglasContrasena.esValida(nueva) else { throw ErrorCuenta.contrasenaDebil }
        try await traducirErrores {
            _ = try await cliente.auth.update(user: UserAttributes(password: nueva))
        }
    }

    public func cerrarSesion() async throws {
        try await traducirErrores {
            try await cliente.auth.signOut()
        }
    }

    public func borrarCuenta() async throws {
        guard let usuario = sesionActual else { return }
        // Las fotos no se borran en cascada desde SQL: se quitan antes con la API de Storage.
        let carpeta = usuario.id.uuidString.lowercased()
        let fotos = cliente.storage.from(Self.bucketFotos)
        try await traducirErrores {
            while true {
                let archivos = try await fotos.list(path: carpeta, options: SearchOptions(limit: 1000))
                guard !archivos.isEmpty else { break }
                _ = try await fotos.remove(paths: archivos.map { "\(carpeta)/\($0.name)" })
            }
            try await cliente.rpc("borrar_mi_cuenta").execute()
        }
        try? await cliente.auth.signOut()
    }

    // MARK: Ayudas

    nonisolated static func sesion(_ sesion: Session) -> SesionUsuario {
        SesionUsuario(id: sesion.user.id, correo: sesion.user.email)
    }

    nonisolated static func correoValido(_ correo: String) throws -> String {
        let normalizado = ValidadorCorreo.normalizar(correo)
        guard ValidadorCorreo.esValido(normalizado) else { throw ErrorCuenta.correoNoValido }
        return normalizado
    }

    private func traducirErrores(_ operacion: () async throws -> Void) async throws {
        do {
            try await operacion()
        } catch let error as ErrorCuenta {
            throw error
        } catch let error as URLError {
            throw Self.traducir(error)
        } catch let error as AuthError {
            throw Self.traducir(error)
        } catch {
            throw ErrorCuenta.otro(error.localizedDescription)
        }
    }

    nonisolated static func traducir(_ error: AuthError) -> ErrorCuenta {
        switch error.errorCode {
        case .invalidCredentials: .credencialesIncorrectas
        case .emailNotConfirmed: .correoSinConfirmar
        case .userAlreadyExists, .emailExists: .correoYaRegistrado
        case .weakPassword: .contrasenaDebil
        default: .otro(error.localizedDescription)
        }
    }

    nonisolated static func traducir(_ error: URLError) -> ErrorCuenta {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
            .sinConexion
        default:
            .otro(error.localizedDescription)
        }
    }
}
