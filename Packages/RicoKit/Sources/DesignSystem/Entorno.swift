import SwiftUI

// Valores compartidos entre módulos sin que dependan unos de otros.
// La app los rellena en la raíz (ver App/RaizView.swift).

public extension EnvironmentValues {
    /// La cuenta tiene Rico Premium: sin límites del plan gratis.
    @Entry var esPremium: Bool = false

    /// Abre la pantalla de Rico Premium (el «paywall»). Por defecto no hace nada.
    @Entry var pedirPremium: AccionPremium = AccionPremium {}
}

/// Acción para abrir la pantalla de Premium desde cualquier módulo.
public struct AccionPremium: Sendable {
    private let accion: @MainActor @Sendable () -> Void

    public init(_ accion: @escaping @MainActor @Sendable () -> Void) {
        self.accion = accion
    }

    @MainActor
    public func callAsFunction() { accion() }
}

// MARK: Hoja de Premium desde cualquier nivel

public extension EnvironmentValues {
    /// Contenido de la hoja de Premium (la `PaywallView`). Lo pone la raíz de la app.
    @Entry var hojaPremium: HojaPremium? = nil
}

/// Qué se muestra al pedir Premium. Así los módulos no dependen del módulo Premium.
public struct HojaPremium: Sendable {
    let contenido: @MainActor @Sendable () -> AnyView

    public init<Contenido: View>(@ViewBuilder _ contenido: @escaping @MainActor @Sendable () -> Contenido) {
        self.contenido = { AnyView(contenido()) }
    }
}

public extension View {
    /// Hace que `pedirPremium` abra la hoja de Premium desde esta vista.
    ///
    /// SwiftUI solo presenta una hoja por nivel: si una vista ya está dentro de una hoja
    /// (la ficha rápida, la cuenta), la de Premium tiene que salir desde ahí, no desde la raíz.
    func permitePedirPremium() -> some View {
        modifier(PermitePedirPremium())
    }
}

private struct PermitePedirPremium: ViewModifier {
    @Environment(\.hojaPremium) private var hoja
    @Environment(\.pedirPremium) private var heredada
    @State private var mostrando = false

    func body(content: Content) -> some View {
        content
            .environment(\.pedirPremium, hoja == nil ? heredada : AccionPremium { mostrando = true })
            .sheet(isPresented: $mostrando) { hoja?.contenido() }
    }
}
