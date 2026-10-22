import SwiftUI
import Testing
import UIKit
import DesignSystem

@Suite("Tipografía")
struct TipografiaTests {
    /// Si una fuente no se registra, SwiftUI pinta en la del sistema sin avisar: la CI pasa y
    /// la app se ve con otra letra. Esta prueba lo detecta.
    @Test(arguments: [
        "BricolageTexto-Regular", "BricolageTexto-Medium", "BricolageTexto-SemiBold", "BricolageTexto-Bold",
        "BricolageTitular-SemiBold", "BricolageTitular-Bold", "BricolageTitular-ExtraBold",
    ])
    func fuentesDeBricolageRegistradas(nombre: String) {
        _ = Font.rico(.body)
        #expect(UIFont(name: nombre, size: 17) != nil)
    }
}
