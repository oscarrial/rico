import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import Visitas

/// Lo que se abre al tocar el aviso «¿Qué tal en…?»: la ficha rápida de esa visita,
/// o primero «¿Dónde fue?» si aún no tiene sitio.
public struct ValorarVisitaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query private var encontradas: [Visita]

    public init(visitaID: UUID) {
        _encontradas = Query(filter: #Predicate<Visita> { $0.id == visitaID })
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let visita = encontradas.first {
                    if visita.restaurante != nil {
                        ficha(visita)
                    } else {
                        // Al elegir el sitio la visita ya tiene restaurante y se pasa sola a la ficha.
                        ElegirSitioView(visita: visita) { _ in }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
                                }
                            }
                    }
                } else {
                    noEsta
                }
            }
        }
        .tint(.ricoTomate)
    }

    private func ficha(_ visita: Visita) -> some View {
        FichaRapidaView(modelo: FichaRapidaModelo(visita: visita)) { guardada in
            NotificadorLocal().cancelar(visitaID: guardada.id)
            do {
                try AccionesBandeja.confirmar(guardada, en: contexto)
            } catch {
                Registro.captura.error("No se pudo confirmar el sitio: \(String(describing: error), privacy: .public)")
            }
            cerrar()
        }
    }

    private var noEsta: some View {
        ContentUnavailableView {
            Label { Text("Esta visita ya no está", bundle: .module) } icon: { Image(systemName: "fork.knife") }
        } description: {
            Text("Puede que ya la descartaras o que sea de otra cuenta.", bundle: .module)
        }
        .background(Color.ricoFondo)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { cerrar() } label: { Text("Cerrar", bundle: .module) }
            }
        }
    }
}

/// Identificador para presentar la hoja con `sheet(item:)`.
private struct VisitaPorAbrir: Identifiable {
    let id: UUID
}

private struct AbrirVisitaDesdeAviso: ViewModifier {
    @State private var apertura = AperturaVisita.compartida

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { apertura.pendiente.map(VisitaPorAbrir.init) },
            set: { apertura.pendiente = $0?.id }
        )) { item in
            ValorarVisitaView(visitaID: item.id)
        }
    }
}

public extension View {
    /// Abre la ficha de la visita cuando se toca un aviso o un enlace `rico://visita/<uuid>`.
    func abrirVisitaDesdeAviso() -> some View {
        modifier(AbrirVisitaDesdeAviso())
    }
}
