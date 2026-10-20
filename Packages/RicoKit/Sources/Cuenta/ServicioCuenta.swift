import Foundation

/// Usuario con sesión iniciada.
public struct SesionUsuario: Sendable, Equatable {
    public let id: UUID
    public let correo: String?

    public init(id: UUID, correo: String?) {
        self.id = id
        self.correo = correo
    }
}

public enum ErrorCuenta: Error, Equatable {
    case correoNoValido
    case codigoIncorrecto
    case sinConexion
    case appleSinToken
    case otro(String)
}

/// Cuentas de usuario. Protocolo para poder probar sin servidor.
@MainActor
public protocol ServicioCuenta: AnyObject, Sendable {
    var sesionActual: SesionUsuario? { get }
    /// Emite la sesión al empezar y cada vez que cambia (`nil` = sin sesión).
    func cambiosDeSesion() -> AsyncStream<SesionUsuario?>
    func iniciarConApple(tokenIdentidad: String, nonce: String) async throws
    func enviarCodigo(a correo: String) async throws
    func verificarCodigo(_ codigo: String, correo: String) async throws
    func cerrarSesion() async throws
    /// Borra las fotos, la cuenta y todos sus datos en el servidor.
    func borrarCuenta() async throws
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
}
