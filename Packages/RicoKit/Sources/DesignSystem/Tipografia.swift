import SwiftUI

/// Tipografía redondeada del sistema, siempre con estilos de texto para respetar Dynamic Type.
public extension Font {
    static func rico(_ estilo: Font.TextStyle, peso: Font.Weight = .regular) -> Font {
        .system(estilo, design: .rounded, weight: peso)
    }
}

/// Medidas compartidas.
public enum Medidas {
    public static let margen: CGFloat = 20
    public static let radioTarjeta: CGFloat = 20
    public static let radioControl: CGFloat = 14
    public static let alturaBoton: CGFloat = 54
    public static let toqueMinimo: CGFloat = 44
}
