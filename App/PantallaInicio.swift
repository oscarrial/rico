import SwiftUI
import DesignSystem

/// Continúa la pantalla de arranque de iOS (misma imagen, mismo fondo, misma posición)
/// y la retira con un pequeño latido del tomate. Dura medio segundo: es un saludo,
/// no una espera.
struct PantallaInicio: View {
    @Binding var visible: Bool
    @State private var latido = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        // Todo a pantalla completa, como la de iOS, para que el logo no salte al relevarla.
        ZStack {
            Color("FondoInicio")
            Image("Logotipo")
                .scaleEffect(latido ? 1.06 : 1)
                .accessibilityLabel(Text(verbatim: "Rico"))
        }
        .ignoresSafeArea()
        .task {
            if !reducirMovimiento {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { latido = true }
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { latido = false }
            }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.25)) { visible = false }
        }
    }
}
