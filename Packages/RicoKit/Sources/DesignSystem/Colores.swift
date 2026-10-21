import SwiftUI
import UIKit

/// Paleta de Rico, con modo oscuro desde el primer día.
/// Los pares claro/oscuro cumplen contraste AA para texto sobre su fondo.
public extension Color {
    static let ricoTomate = Color(claro: 0xD2381F, oscuro: 0xFF6A4D)
    /// Texto e iconos sobre `ricoTomate`.
    static let ricoSobreTomate = Color(claro: 0xFFFFFF, oscuro: 0x1F0A05)
    static let ricoTomateSuave = Color(claro: 0xFBE3DC, oscuro: 0x4A2219)
    static let ricoTomateTexto = Color(claro: 0xA8291A, oscuro: 0xFF8F78)

    static let ricoFondo = Color(claro: 0xFBF6F0, oscuro: 0x17130F)
    static let ricoSuperficie = Color(claro: 0xFFFFFF, oscuro: 0x241E19)
    static let ricoSuperficieHundida = Color(claro: 0xF3ECE4, oscuro: 0x2E2620)
    static let ricoLinea = Color(claro: 0xEADFD3, oscuro: 0x3A322B)

    static let ricoTinta = Color(claro: 0x1F1A16, oscuro: 0xF5EEE6)
    static let ricoSecundario = Color(claro: 0x6B6158, oscuro: 0xB5A99D)

    static let ricoEstrella = Color(claro: 0xF0A202, oscuro: 0xF5B331)
    static let ricoEstrellaVacia = Color(claro: 0xDCCFC2, oscuro: 0x4A4038)

    /// Verde del cáliz del símbolo. Solo para la marca.
    static let ricoAlbahaca = Color(claro: 0x3F5A30, oscuro: 0x7FA866)

    static let ricoVerde = Color(claro: 0x1F5A37, oscuro: 0x7FD3A0)
    static let ricoVerdeSuave = Color(claro: 0xDDEFE3, oscuro: 0x1D3A28)

    // Pines del mapa por nota. Mismo valor en claro y oscuro: van sobre el mapa con borde blanco
    // y siempre con la nota escrita. Se distinguen también por luminosidad.
    /// Nota media de 4,5 o más.
    static let ricoPinTop = Color(claro: 0xB02A17, oscuro: 0xB02A17)
    /// Nota media de 3,5 a 4,4.
    static let ricoPinBien = Color(claro: 0xEE8A3C, oscuro: 0xEE8A3C)
    /// Nota media por debajo de 3,5.
    static let ricoPinNormal = Color(claro: 0x8E8379, oscuro: 0x8E8379)
    /// Borde e icono del pin «Quiero probar» (relleno blanco).
    static let ricoPinQuieroProbar = Color(claro: 0x2F6FA8, oscuro: 0x2F6FA8)
    /// Texto sobre `ricoPinBien` y `ricoPinNormal` (el blanco no llega a AA). Sobre `ricoPinTop`, blanco.
    static let ricoSobrePin = Color(claro: 0x1F1A16, oscuro: 0x1F1A16)

    /// Colores de relleno cuando una visita aún no tiene foto.
    static let ricoPlaceholders: [Color] = [
        Color(claro: 0xC9573A, oscuro: 0x8E3A26),
        Color(claro: 0x8C6A3F, oscuro: 0x6A4F2E),
        Color(claro: 0x5E7A52, oscuro: 0x46603C),
        Color(claro: 0xB98A4E, oscuro: 0x8A6638),
        Color(claro: 0x7A5C8E, oscuro: 0x5C4470)
    ]
}

extension Color {
    init(claro: UInt32, oscuro: UInt32) {
        self.init(uiColor: UIColor { rasgos in
            UIColor(hex: rasgos.userInterfaceStyle == .dark ? oscuro : claro)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
