import SwiftUI

/// Cabecera de las pantallas raíz (Diario, Listas, Resumen): título grande a la izquierda
/// y las acciones a la derecha, en la misma línea. Va fija arriba con
/// `.cabeceraRaiz { … }` y sustituye a la barra de navegación del sistema.
public struct CabeceraRaiz<Acciones: View, Debajo: View>: View {
    let titulo: Text
    let acciones: Acciones
    let debajo: Debajo

    public init(
        _ titulo: Text,
        @ViewBuilder acciones: () -> Acciones,
        @ViewBuilder debajo: () -> Debajo
    ) {
        self.titulo = titulo
        self.acciones = acciones()
        self.debajo = debajo()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                titulo
                    .font(.rico(.largeTitle, peso: .black))
                    .foregroundStyle(Color.ricoTinta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                HStack(spacing: 10) { acciones }
            }
            debajo
        }
        .padding(.horizontal, Medidas.margen)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ricoFondo)
    }
}

public extension CabeceraRaiz where Debajo == EmptyView {
    init(_ titulo: Text, @ViewBuilder acciones: () -> Acciones) {
        self.init(titulo, acciones: acciones) { EmptyView() }
    }
}

public extension View {
    /// Pone la cabecera fija arriba y oculta la barra de navegación del sistema en esta pantalla
    /// (las pantallas a las que se navega desde aquí siguen teniendo la suya).
    func cabeceraRaiz<Acciones: View, Debajo: View>(_ cabecera: CabeceraRaiz<Acciones, Debajo>) -> some View {
        self
            .safeAreaInset(edge: .top, spacing: 0) { cabecera }
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// Botón redondo de 44 pt para la cabecera (cuenta, nueva lista, ordenar…).
public struct BotonCabecera: View {
    let simbolo: String
    let etiqueta: Text
    let destacado: Bool
    let accion: () -> Void

    public init(simbolo: String, etiqueta: Text, destacado: Bool = false, accion: @escaping () -> Void) {
        self.simbolo = simbolo
        self.etiqueta = etiqueta
        self.destacado = destacado
        self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(destacado ? Color.ricoSobreTomate : Color.ricoTinta)
                .frame(width: Medidas.toqueMinimo, height: Medidas.toqueMinimo)
                .background(destacado ? Color.ricoTomate : Color.ricoSuperficie, in: Circle())
                .overlay {
                    if !destacado { Circle().strokeBorder(Color.ricoLinea) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
    }
}

/// Campo de búsqueda propio para las cabeceras (la búsqueda del sistema necesita la barra
/// de navegación, que en las pantallas raíz no se usa).
public struct CampoBusqueda: View {
    @Binding var texto: String
    let ejemplo: Text

    public init(texto: Binding<String>, ejemplo: Text) {
        _texto = texto
        self.ejemplo = ejemplo
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .accessibilityHidden(true)
            TextField(text: $texto, prompt: ejemplo) { ejemplo }
                .font(.rico(.body, peso: .semibold))
                .foregroundStyle(Color.ricoTinta)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !texto.isEmpty {
                Button {
                    texto = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.ricoSecundario)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Borrar búsqueda", bundle: .module))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
        .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
    }
}
