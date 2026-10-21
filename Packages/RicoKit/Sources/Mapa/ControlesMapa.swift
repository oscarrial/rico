import SwiftUI
import DesignSystem
import RicoCore

// Controles que flotan sobre el mapa: cristal en iOS 26 y relleno sólido con sombra antes.
// Ver DESIGN.md § Liquid Glass.

/// Agrupa varios controles de cristal para que se fundan entre sí (iOS 26).
struct ContenedorCristal<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) { contenido }
        } else {
            contenido
        }
    }
}

extension View {
    /// Fondo de un control que flota sobre el mapa, sin tinte.
    @ViewBuilder
    func fondoFlotante<Forma: Shape>(_ forma: Forma) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: forma)
        } else {
            self
                .background(Color.ricoSuperficie, in: forma)
                .overlay(forma.stroke(Color.ricoLinea, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

/// Pin del mapa: nota escrita sobre el color de su categoría, o un icono en «Quiero probar» y «Explorar».
struct PinMapaView: View {
    let categoria: CategoriaPin
    let nota: Double?
    let seleccionado: Bool

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        contenido
            .font(.rico(.caption, peso: .heavy))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(minWidth: 32, minHeight: 28)
            .foregroundStyle(primerPlano)
            .background(fondo, in: Capsule())
            .overlay(Capsule().strokeBorder(borde, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .scaleEffect(seleccionado && !reducirMovimiento ? 1.2 : 1)
            .animation(.snappy(duration: 0.25), value: seleccionado)
            .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
            .contentShape(Rectangle())
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    @ViewBuilder
    private var contenido: some View {
        switch categoria {
        case .quieroProbar:
            Image(systemName: "bookmark.fill")
        case .explorar:
            Image(systemName: "fork.knife")
        case .top, .bien, .normal:
            Text(verbatim: nota.map(NotaTexto.texto) ?? "–")
        }
    }

    private var fondo: Color {
        switch categoria {
        case .top: .ricoPinTop
        case .bien: .ricoPinBien
        case .normal: .ricoPinNormal
        case .quieroProbar: .white
        case .explorar: .ricoSuperficie
        }
    }

    private var primerPlano: Color {
        switch categoria {
        case .top: .white
        case .bien, .normal: .ricoSobrePin
        case .quieroProbar: .ricoPinQuieroProbar
        case .explorar: .ricoSecundario
        }
    }

    private var borde: Color {
        switch categoria {
        case .top, .bien, .normal: .white
        case .quieroProbar: .ricoPinQuieroProbar
        case .explorar: .ricoLinea
        }
    }
}
