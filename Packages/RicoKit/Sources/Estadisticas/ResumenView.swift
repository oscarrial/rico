import SwiftUI
import DesignSystem

/// Pestaña Resumen: gasto y visitas del mes.
public struct ResumenView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label { Text("Resumen", bundle: .module) } icon: { Image(systemName: "chart.bar") }
            }
            .background(Color.ricoFondo)
            .navigationTitle(Text("Resumen", bundle: .module))
        }
    }
}
