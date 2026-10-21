import SwiftUI
import DesignSystem

/// Pestaña Mapa: tus sitios con pines por nota y «Explorar zona».
public struct MapaView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label { Text("Mapa", bundle: .module) } icon: { Image(systemName: "map") }
            }
            .background(Color.ricoFondo)
            .navigationTitle(Text("Mapa", bundle: .module))
        }
    }
}
