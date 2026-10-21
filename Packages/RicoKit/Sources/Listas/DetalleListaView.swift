import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Los restaurantes de una lista, por nombre, con tu nota media y la ciudad.
struct DetalleListaView: View {
    let lista: Lista

    @Environment(\.modelContext) private var contexto

    private var restaurantes: [Restaurante] {
        (lista.restaurantes ?? []).sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending }
    }

    var body: some View {
        let ordenados = restaurantes
        List {
            ForEach(ordenados) { restaurante in
                NavigationLink(value: restaurante) {
                    FilaRestauranteLista(restaurante: restaurante)
                }
                .listRowBackground(Color.ricoSuperficie)
                .swipeActions(edge: .trailing) {
                    Button {
                        try? contexto.quitar(restaurante, de: lista)
                    } label: {
                        Label { Text("Quitar", bundle: .module) } icon: { Image(systemName: "bookmark.slash") }
                    }
                    .tint(Color.ricoSecundario)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ricoFondo)
        .overlay {
            if ordenados.isEmpty { vacio }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.large)
    }

    private var titulo: Text {
        if lista.tipo == .propia, let emoji = lista.emoji {
            return Text(verbatim: "\(emoji) \(lista.nombre)")
        }
        return NombreLista.texto(lista)
    }

    private var vacio: some View {
        ContentUnavailableView {
            Label {
                Text("Aún no hay sitios", bundle: .module)
            } icon: {
                Image(systemName: "bookmark")
            }
        } description: {
            Text("Abre un restaurante desde el diario o el mapa y pulsa el marcador para guardarlo aquí.", bundle: .module)
        }
    }
}

/// Fila de un restaurante en una lista: nombre, ciudad y tu nota media.
struct FilaRestauranteLista: View {
    let restaurante: Restaurante

    var body: some View {
        let resumen = ResumenRestaurante(restaurante: restaurante)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(restaurante.nombre)
                    .font(.rico(.headline, peso: .heavy))
                    .foregroundStyle(Color.ricoTinta)
                if let ciudad = restaurante.ciudad, !ciudad.isEmpty {
                    Text(ciudad)
                        .font(.rico(.footnote, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                }
            }
            Spacer()
            if let nota = resumen.notaMedia {
                NotaCompacta(nota: nota)
                    .foregroundStyle(Color.ricoTinta)
            } else {
                Text("Sin probar", bundle: .module)
                    .font(.rico(.caption, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
            }
        }
        .frame(minHeight: Medidas.toqueMinimo)
        .accessibilityElement(children: .combine)
    }
}
