import CryptoKit
import Foundation

/// Nonce de «Iniciar sesión con Apple»: Apple recibe el SHA-256 y Supabase el original,
/// así un token robado no se puede reutilizar.
public enum Nonce {
    static let caracteres = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    public static func aleatorio(longitud: Int = 32) -> String {
        var generador = SystemRandomNumberGenerator()
        return String((0..<longitud).map { _ in caracteres.randomElement(using: &generador)! })
    }

    public static func sha256(_ texto: String) -> String {
        SHA256.hash(data: Data(texto.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
