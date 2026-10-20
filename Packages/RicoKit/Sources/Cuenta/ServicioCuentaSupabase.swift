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

    public func enviarCodigo(a correo: String) async throws {
        let correo = correo.trimmingCharacters(in: .whitespaces).lowercased()
        guard ValidadorCorreo.esValido(correo) else { throw ErrorCuenta.correoNoValido }
        try await traducirErrores {
            try await cliente.auth.signInWithOTP(email: correo, shouldCreateUser: true)
        }
    }

    public func verificarCodigo(_ codigo: String, correo: String) async throws {
        let correo = correo.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            _ = try await cliente.auth.verifyOTP(email: correo, token: codigo, type: .email)
        } catch let error as URLError {
            throw Self.traducir(error)
        } catch {
            throw ErrorCuenta.codigoIncorrecto
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

    private func traducirErrores(_ operacion: () async throws -> Void) async throws {
        do {
            try await operacion()
        } catch let error as ErrorCuenta {
            throw error
        } catch let error as URLError {
            throw Self.traducir(error)
        } catch {
            throw ErrorCuenta.otro(error.localizedDescription)
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
