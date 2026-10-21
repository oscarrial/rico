import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore

/// Nombre de una lista con su emoji. «Quiero probar» se muestra traducido.
public struct NombreLista: View {
    let lista: Lista

    public init(_ lista: Lista) {
        self.lista = lista
    }

    public var body: some View {
        HStack(spacing: 12) {
            simbolo
                .frame(width: 28)
                .accessibilityHidden(true)
            NombreLista.texto(lista)
                .font(.rico(.body, peso: .bold))
                .foregroundStyle(Color.ricoTinta)
        }
    }

    /// Nombre visible de la lista, sin emoji.
    public static func texto(_ lista: Lista) -> Text {
        lista.tipo == .quieroProbar ? Text("Quiero probar", bundle: .module) : Text(verbatim: lista.nombre)
    }

    @ViewBuilder
    private var simbolo: some View {
        if lista.tipo == .quieroProbar {
            Image(systemName: "bookmark.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ricoTinta)
        } else if let emoji = lista.emoji {
            Text(verbatim: emoji)
                .font(.title3)
        } else {
            Image(systemName: "list.bullet")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ricoSecundario)
        }
    }
}

/// Hoja para crear una lista propia o cambiar su nombre y emoji.
/// Quien la abre comprueba antes el límite del plan gratis.
public struct EditorListaView: View {
    /// Emojis para elegir: pocos y de comida, para que la lista se reconozca de un vistazo.
    public static let emojis = ["🍕", "🍣", "🍷", "🥘", "🍔", "🌮", "🍜", "🥐", "🍰", "☕️", "🍺", "🦐"]

    private let lista: Lista?
    private let alGuardar: (Lista) -> Void

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.esPremium) private var esPremium

    @State private var nombre: String
    @State private var emoji: String?
    @State private var fallo = false
    @FocusState private var enfocado: Bool

    /// - Parameters:
    ///   - lista: la lista que se edita; `nil` para crear una nueva.
    ///   - alGuardar: se llama con la lista creada o editada, ya guardada.
    public init(lista: Lista? = nil, alGuardar: @escaping (Lista) -> Void = { _ in }) {
        self.lista = lista
        self.alGuardar = alGuardar
        _nombre = State(initialValue: lista?.nombre ?? "")
        _emoji = State(initialValue: lista?.emoji)
    }

    private var puedeGuardar: Bool { !nombre.recortado.isEmpty }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre", bundle: .module)
                            .font(.rico(.footnote, peso: .heavy))
                            .foregroundStyle(Color.ricoSecundario)
                        TextField(text: $nombre, prompt: Text("Cenas especiales", bundle: .module)) {
                            Text("Nombre", bundle: .module)
                        }
                        .font(.rico(.body, peso: .bold))
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($enfocado)
                        .onSubmit(guardar)
                        .padding(.horizontal, 16)
                        .frame(minHeight: Medidas.alturaBoton)
                        .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                        .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emoji (opcional)", bundle: .module)
                            .font(.rico(.footnote, peso: .heavy))
                            .foregroundStyle(Color.ricoSecundario)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                            botonEmoji(nil)
                            ForEach(Self.emojis, id: \.self) { botonEmoji($0) }
                        }
                        .sensoryFeedback(.selection, trigger: emoji)
                    }
                }
                .padding(.horizontal, Medidas.margen)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ricoFondo)
            .safeAreaInset(edge: .bottom) {
                Button(action: guardar) {
                    if lista == nil {
                        Text("Crear lista", bundle: .module)
                    } else {
                        Text("Guardar cambios", bundle: .module)
                    }
                }
                .buttonStyle(.ricoPrincipal)
                .disabled(!puedeGuardar)
                .padding(.horizontal, Medidas.margen)
                .padding(.vertical, 12)
                .fondoBarraInferior()
            }
            .navigationTitle(lista == nil ? Text("Nueva lista", bundle: .module) : Text("Editar lista", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancelar", bundle: .module) }
                }
            }
            .alert(Text("No se ha podido guardar la lista", bundle: .module), isPresented: $fallo) {
                Button { } label: { Text("Entendido", bundle: .module) }
            } message: {
                Text("Prueba otra vez en un momento.", bundle: .module)
            }
            .onAppear { if lista == nil { enfocado = true } }
        }
        .presentationDetents([.medium, .large])
    }

    private func botonEmoji(_ valor: String?) -> some View {
        let elegido = emoji == valor
        return Button {
            emoji = valor
        } label: {
            Group {
                if let valor {
                    Text(verbatim: valor)
                        .font(.title2)
                } else {
                    Image(systemName: "nosign")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ricoSecundario)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                elegido ? Color.ricoTomateSuave : Color.ricoSuperficie,
                in: RoundedRectangle(cornerRadius: Medidas.radioControl)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Medidas.radioControl)
                    .strokeBorder(elegido ? Color.ricoTomate : Color.ricoLinea, lineWidth: elegido ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(valor.map { Text(verbatim: $0) } ?? Text("Sin emoji", bundle: .module))
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }

    private func guardar() {
        guard puedeGuardar else { return }
        do {
            let guardada: Lista
            if let lista {
                try contexto.renombrar(lista, nombre: nombre, emoji: emoji)
                guardada = lista
            } else {
                guardada = try contexto.crearLista(nombre: nombre, emoji: emoji, esPremium: esPremium)
            }
            alGuardar(guardada)
            dismiss()
        } catch {
            fallo = true
        }
    }
}
