import Foundation

/// Usuario con sesión iniciada.
public struct SesionUsuario: Sendable, Equatable {
    public let id: UUID
    public let correo: String?
    /// Cómo entró: `"email"`, `"apple"`… (`nil` si no se sabe).
    public let proveedor: String?

    public init(id: UUID, correo: String?, proveedor: String? = nil) {
        self.id = id
        self.correo = correo
        self.proveedor = proveedor
    }
}

public enum ErrorCuenta: Error, Equatable {
    case correoNoValido
    case credencialesIncorrectas
    case correoSinConfirmar
    case correoYaRegistrado
    case contrasenaDebil
    case enlaceNoValido
    case sinConexion
    case appleSinToken
    case otro(String)
}

/// Qué pasa tras crear la cuenta.
public enum ResultadoRegistro: Sendable, Equatable {
    /// La cuenta queda lista y con sesión.
    case sesionIniciada
    /// Hay que abrir el enlace que ha llegado al correo.
    case confirmaTuCorreo
}

/// Enlaces de los correos que vuelven a la app (`rico://auth/...`).
public enum EnlaceCuenta: Sendable, Equatable {
    case confirmacion
    case recuperacion

    public static let esquema = "rico"
    public static let urlConfirmacion = URL(string: "rico://auth/confirmar")!
    public static let urlRecuperacion = URL(string: "rico://auth/recuperar")!

    /// Reconoce un enlace de cuenta por su ruta.
    public init?(url: URL) {
        guard url.scheme == Self.esquema, url.host == "auth" else { return nil }
        switch url.path {
        case "/confirmar": self = .confirmacion
        case "/recuperar": self = .recuperacion
        default: return nil
        }
    }
}

/// Cuentas de usuario. Protocolo para poder probar sin servidor.
@MainActor
public protocol ServicioCuenta: AnyObject, Sendable {
    var sesionActual: SesionUsuario? { get }
    /// Emite la sesión al empezar y cada vez que cambia (`nil` = sin sesión).
    func cambiosDeSesion() -> AsyncStream<SesionUsuario?>
    func iniciarConApple(tokenIdentidad: String, nonce: String) async throws
    func registrar(correo: String, contrasena: String) async throws -> ResultadoRegistro
    func iniciarSesion(correo: String, contrasena: String) async throws
    func enviarRecuperacion(a correo: String) async throws
    /// Abre la sesión que trae un enlace de confirmación o de recuperación.
    func gestionarEnlace(_ url: URL) async throws -> EnlaceCuenta
    func cambiarContrasena(_ nueva: String) async throws
    func cerrarSesion() async throws
    /// Borra las fotos, la cuenta y todos sus datos en el servidor, y revoca el acceso de Apple
    /// si se pasa un código nuevo de «Iniciar sesión con Apple». No cierra la sesión.
    func borrarCuenta(codigoApple: String?) async throws
}

public enum ValidadorCorreo {
    /// Comprobación básica: algo@algo.dominio, sin espacios.
    public static func esValido(_ correo: String) -> Bool {
        let partes = correo.split(separator: "@", omittingEmptySubsequences: false)
        guard partes.count == 2, !partes[0].isEmpty, !correo.contains(" ") else { return false }
        let dominio = partes[1]
        guard let punto = dominio.lastIndex(of: "."), punto != dominio.startIndex else { return false }
        return dominio.distance(from: punto, to: dominio.endIndex) > 2
    }

    public static func normalizar(_ correo: String) -> String {
        correo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Reglas de contraseña. Las mismas se configuran en Supabase (Auth → Policies),
/// que es quien las hace cumplir; aquí solo se enseñan mientras se escribe.
public enum ReglasContrasena {
    public enum Regla: CaseIterable, Sendable {
        case longitud
        case letra
        case numero
    }

    public static let longitudMinima = 8

    public static func cumple(_ regla: Regla, _ contrasena: String) -> Bool {
        switch regla {
        case .longitud: contrasena.count >= longitudMinima
        case .letra: contrasena.contains(where: \.isLetter)
        case .numero: contrasena.contains(where: \.isNumber)
        }
    }

    public static func esValida(_ contrasena: String) -> Bool {
        Regla.allCases.allSatisfy { cumple($0, contrasena) }
    }
}
