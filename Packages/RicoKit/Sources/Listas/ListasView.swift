import SwiftUI
import DesignSystem

/// Pestaña Listas: «Quiero probar» y listas propias.
public struct ListasView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label { Text("Listas", bundle: .module) } icon: { Image(systemName: "bookmark") }
            }
            .background(Color.ricoFondo)
            .navigationTitle(Text("Listas", bundle: .module))
        }
    }
}
