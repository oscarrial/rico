import SwiftUI

// Liquid Glass (iOS 26) solo en la capa de navegación: lo que flota sobre el contenido.
// Las tarjetas, listas y fotos son contenido y siguen siendo sólidas. Ver DESIGN.md § Liquid Glass.

/// Botón redondo flotante (el + del diario).
public struct BotonFlotante: View {
    let simbolo: String
    let etiqueta: Text
    let accion: () -> Void

    public init(simbolo: String, etiqueta: Text, accion: @escaping () -> Void) {
        self.simbolo = simbolo
        self.etiqueta = etiqueta
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.ricoSobreTomate)
                .frame(width: 60, height: 60)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(FondoBotonFlotante())
        .accessibilityLabel(etiqueta)
    }
}

private struct FondoBotonFlotante: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.ricoTomate).interactive(), in: Circle())
        } else {
            content
                .background(Color.ricoTomate, in: Circle())
                .shadow(color: Color.ricoTomate.opacity(0.35), radius: 10, y: 6)
        }
    }
}

public extension View {
    /// Fondo de la barra de acción fija abajo: un degradado hacia el color del lienzo
    /// para que el contenido se apague bajo el botón en vez de asomar por los lados.
    func fondoBarraInferior() -> some View {
        self.background {
            LinearGradient(
                stops: [
                    .init(color: Color.ricoFondo.opacity(0), location: 0),
                    .init(color: Color.ricoFondo.opacity(0.85), location: 0.35),
                    .init(color: Color.ricoFondo, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.top, -28)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
