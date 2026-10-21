import SwiftUI
import DesignSystem

/// Pantalla de Rico Premium.
public struct PaywallView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView {
            Label { Text("Rico Premium", bundle: .module) } icon: { Image(systemName: "star") }
        }
        .background(Color.ricoFondo)
    }
}
