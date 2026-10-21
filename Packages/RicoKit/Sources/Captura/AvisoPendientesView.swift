import SwiftUI
import SwiftData
import DesignSystem
import Modelos

/// Aviso en lo alto del diario cuando hay visitas por valorar. Abre la bandeja.
/// No ocupa nada si no hay pendientes.
public struct AvisoPendientesView: View {
    @Query(filter: #Predicate<Visita> { $0.estadoRaw == "borrador" })
    private var pendientes: [Visita]

    @State private var mostrandoBandeja = false

    public init() {}

    public var body: some View {
        // Mientras la bandeja está abierta el aviso se mantiene, aunque ya no quede nada:
        // si desapareciera, la hoja se cerraría de golpe.
        if !pendientes.isEmpty || mostrandoBandeja {
            Button {
                mostrandoBandeja = true
            } label: {
                tarjeta
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $mostrandoBandeja) {
                BandejaPendientesView()
            }
        }
    }

    private var tarjeta: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ricoSobreTomate)
                .frame(width: 40, height: 40)
                .background(Color.ricoTomate, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tienes ^[\(pendientes.count) visita](inflect: true) por valorar", bundle: .module)
                    .font(.rico(.subheadline, peso: .heavy))
                    .foregroundStyle(Color.ricoTomateTexto)
                Text("Diez segundos y queda en tu diario", bundle: .module)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoTinta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ricoTomateTexto)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(minHeight: Medidas.toqueMinimo)
        .background(Color.ricoTomateSuave, in: RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        .contentShape(RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Abre las visitas por valorar", bundle: .module))
    }
}
