import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Pestaña Listas: «Quiero probar» arriba y debajo tus listas, en el orden que elijas.
public struct ListasView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.esPremium) private var esPremium
    @Environment(\.pedirPremium) private var pedirPremium

    @Query(filter: #Predicate<Lista> { $0.tipoRaw == "quieroProbar" }, sort: \Lista.fechaCreacion)
    private var quieroProbar: [Lista]

    @Query(filter: #Predicate<Lista> { $0.tipoRaw == "propia" }, sort: \Lista.orden)
    private var propias: [Lista]

    @State private var creando = false
    @State private var editando: Lista?
    @State private var paraBorrar: Lista?
    @State private var reordenando = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if let lista = quieroProbar.first {
                    Section {
                        NavigationLink(value: lista) { FilaLista(lista: lista) }
                            .listRowBackground(Color.ricoSuperficie)
                    }
                }

                Section {
                    ForEach(propias) { lista in
                        NavigationLink(value: lista) { FilaLista(lista: lista) }
                            .listRowBackground(Color.ricoSuperficie)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { paraBorrar = lista } label: {
                                    Label { Text("Borrar", bundle: .module) } icon: { Image(systemName: "trash") }
                                }
                                .tint(Color.ricoTomate)
                                Button { editando = lista } label: {
                                    Label { Text("Editar", bundle: .module) } icon: { Image(systemName: "pencil") }
                                }
                                .tint(Color.ricoSecundario)
                            }
                            .contextMenu {
                                Button { editando = lista } label: {
                                    Label { Text("Editar", bundle: .module) } icon: { Image(systemName: "pencil") }
                                }
                                Button(role: .destructive) { paraBorrar = lista } label: {
                                    Label { Text("Borrar", bundle: .module) } icon: { Image(systemName: "trash") }
                                }
                            }
                    }
                    .onMove(perform: mover)

                    if propias.isEmpty {
                        vacio
                            .listRowBackground(Color.ricoSuperficie)
                    }
                } header: {
                    TituloSeccion(Text("Tus listas", bundle: .module))
                } footer: {
                    if !esPremium {
                        Text("\(propias.count) de \(LimitesGratis.listasPropias) listas", bundle: .module)
                            .font(.rico(.footnote, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ricoFondo)
            .environment(\.editMode, .constant(reordenando ? EditMode.active : .inactive))
            .cabeceraRaiz(
                CabeceraRaiz(Text("Listas", bundle: .module)) {
                    if !propias.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { reordenando.toggle() }
                        } label: {
                            if reordenando {
                                Text("Listo", bundle: .module)
                            } else {
                                Text("Editar", bundle: .module)
                            }
                        }
                        .font(.rico(.subheadline, peso: .heavy))
                        .foregroundStyle(Color.ricoTomateTexto)
                        .frame(minHeight: Medidas.toqueMinimo)
                    }
                    BotonCabecera(
                        simbolo: "plus",
                        etiqueta: Text("Nueva lista", bundle: .module),
                        destacado: true,
                        accion: nuevaLista
                    )
                }
            )
            .navigationDestination(for: Lista.self) { lista in
                DetalleListaView(lista: lista)
            }
            .navigationDestination(for: Restaurante.self) { restaurante in
                FichaRestauranteView(restaurante: restaurante)
            }
            .task { _ = try? contexto.listaQuieroProbar() }
            .sheet(isPresented: $creando) {
                EditorListaView()
            }
            .sheet(item: $editando) { lista in
                EditorListaView(lista: lista)
            }
            .confirmationDialog(
                Text("¿Borrar la lista?", bundle: .module),
                isPresented: Binding(get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }),
                titleVisibility: .visible,
                presenting: paraBorrar
            ) { lista in
                Button(role: .destructive) {
                    try? contexto.borrar(lista)
                } label: {
                    Text("Borrar lista", bundle: .module)
                }
            } message: { _ in
                Text("Los restaurantes seguirán en tu diario.", bundle: .module)
            }
        }
    }

    // MARK: Vistas

    private var vacio: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Agrupa sitios a tu manera: para ir con amigos, cenas especiales o de viaje.", bundle: .module)
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
            Button(action: nuevaLista) {
                Text("Crear una lista", bundle: .module)
                    .font(.rico(.body, peso: .heavy))
                    .foregroundStyle(Color.ricoTomateTexto)
                    .frame(minHeight: Medidas.toqueMinimo)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    // MARK: Acciones

    private func nuevaLista() {
        if esPremium || propias.count < LimitesGratis.listasPropias {
            creando = true
        } else {
            pedirPremium()
        }
    }

    private func mover(desde origen: IndexSet, hasta destino: Int) {
        var nuevas = propias
        nuevas.move(fromOffsets: origen, toOffset: destino)
        try? contexto.ordenar(nuevas)
    }
}

/// Fila de una lista: emoji, nombre y número de sitios.
struct FilaLista: View {
    let lista: Lista

    var body: some View {
        let sitios = lista.restaurantes?.count ?? 0
        HStack {
            NombreLista(lista)
            Spacer()
            Text("^[\(sitios) sitio](inflect: true)", bundle: .module)
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
        }
        .frame(minHeight: Medidas.toqueMinimo)
        .accessibilityElement(children: .combine)
    }
}
