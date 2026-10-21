import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore

/// Hoja para guardar un restaurante en tus listas: marca o desmarca cada una.
struct SelectorListasView: View {
    let restaurante: Restaurante

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.esPremium) private var esPremium
    @Environment(\.pedirPremium) private var pedirPremium

    @Query(sort: \Lista.orden)
    private var listas: [Lista]

    @State private var creando = false
    @State private var cambios = 0

    /// «Quiero probar» primero y después las propias, por orden.
    private var ordenadas: [Lista] {
        listas.filter { $0.tipo == .quieroProbar } + listas.filter { $0.tipo == .propia }
    }

    private var propias: Int { listas.filter { $0.tipo == .propia }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordenadas) { lista in
                        fila(lista)
                            .listRowBackground(Color.ricoSuperficie)
                    }
                }

                Section {
                    Button(action: nuevaLista) {
                        Label {
                            Text("Nueva lista", bundle: .module)
                                .font(.rico(.body, peso: .bold))
                        } icon: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(Color.ricoTinta)
                        .frame(minHeight: Medidas.toqueMinimo)
                    }
                    .listRowBackground(Color.ricoSuperficie)
                } footer: {
                    if !esPremium {
                        Text("\(propias) de \(LimitesGratis.listasPropias) listas", bundle: .module)
                            .font(.rico(.footnote, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ricoFondo)
            .sensoryFeedback(.selection, trigger: cambios)
            .navigationTitle(Text("Guardar en una lista", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Hecho", bundle: .module) }
                }
            }
            .task { _ = try? contexto.listaQuieroProbar() }
            .sheet(isPresented: $creando) {
                EditorListaView { nueva in
                    try? contexto.anadir(restaurante, a: nueva)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func fila(_ lista: Lista) -> some View {
        let dentro = lista.contiene(restaurante)
        return Button {
            if dentro {
                try? contexto.quitar(restaurante, de: lista)
            } else {
                try? contexto.anadir(restaurante, a: lista)
            }
            cambios += 1
        } label: {
            HStack {
                NombreLista(lista)
                Spacer()
                Image(systemName: dentro ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(dentro ? Color.ricoTomate : Color.ricoSecundario)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Medidas.toqueMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(dentro ? .isSelected : [])
        .accessibilityHint(dentro ? Text("Quitar de esta lista", bundle: .module) : Text("Guardar en esta lista", bundle: .module))
    }

    private func nuevaLista() {
        if (try? contexto.puedeCrearListaPropia(esPremium: esPremium)) ?? true {
            creando = true
        } else {
            // Premium se abre desde la raíz: primero se cierra esta hoja.
            let pedir = pedirPremium
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                pedir()
            }
        }
    }
}
