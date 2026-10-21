import Foundation
import Observation

/// Estado de la suscripción a Rico Premium.
@MainActor
@Observable
public final class EstadoPremium {
    public private(set) var esPremium = false

    public init() {}
}
