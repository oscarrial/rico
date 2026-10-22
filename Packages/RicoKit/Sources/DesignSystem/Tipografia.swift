import CoreText
import OSLog
import SwiftUI

/// Bricolage Grotesque, siempre con estilos de texto para respetar Dynamic Type (DESIGN.md §4).
///
/// Los cortes van en `Resources/Fuentes`: «Texto» (tamaño óptico 14) para todo lo pequeño y
/// «Titular» (tamaño óptico 32) para los títulos. Se generan a partir de la fuente variable de
/// Google Fonts (licencia OFL, en `Resources/Fuentes/OFL.txt`).
public extension Font {
    static func rico(_ estilo: Font.TextStyle, peso: Font.Weight = .regular) -> Font {
        FuentesRico.registrar()
        return .custom(FuentesRico.nombre(estilo: estilo, peso: peso), size: FuentesRico.tamano(estilo), relativeTo: estilo)
    }
}

enum FuentesRico {
    private static let registroFuentes = Logger(subsystem: "es.rico.app", category: "diseno")

    /// Se registran una sola vez, la primera vez que se pide una fuente.
    /// Xcode copia los recursos procesados a la raíz del bundle (sin la carpeta `Fuentes`), así
    /// que se buscan en los dos sitios y se juntan.
    private static let registro: Void = {
        let enCarpeta = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fuentes") ?? []
        let enRaiz = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in Set(enCarpeta + enRaiz) {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                registroFuentes.error("No se pudo registrar \(url.lastPathComponent, privacy: .public): \(String(describing: error?.takeRetainedValue()), privacy: .public)")
            }
        }
    }()

    static func registrar() {
        _ = registro
    }

    /// Los títulos usan el corte de titular; el resto, el de texto.
    private static func esTitular(_ estilo: Font.TextStyle) -> Bool {
        switch estilo {
        case .largeTitle, .title, .title2, .title3: true
        default: false
        }
    }

    /// Cada peso baja un escalón respecto al que se pide: la marca sigue siendo gruesa, pero sin
    /// gritar (los `black` y `heavy` de las vistas se quedan como están).
    static func nombre(estilo: Font.TextStyle, peso: Font.Weight) -> String {
        if esTitular(estilo) {
            switch peso {
            case .black: return "BricolageTitular-ExtraBold"
            case .heavy: return "BricolageTitular-Bold"
            default: return "BricolageTitular-SemiBold"
            }
        }
        switch peso {
        case .black, .heavy: return "BricolageTexto-Bold"
        case .bold: return "BricolageTexto-SemiBold"
        case .semibold, .medium: return "BricolageTexto-Medium"
        default: return "BricolageTexto-Regular"
        }
    }

    /// Tamaño de cada estilo con la letra por defecto («Grande»); `relativeTo` lo escala.
    static func tamano(_ estilo: Font.TextStyle) -> CGFloat {
        switch estilo {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
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
