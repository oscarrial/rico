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
