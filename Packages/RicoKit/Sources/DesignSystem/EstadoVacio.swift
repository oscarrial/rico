import SwiftUI

/// Estado vacío o de aviso a pantalla completa: icono (o el símbolo de Rico), título, qué hacer y,
/// si hace falta, una acción. Es `ContentUnavailableView` con la tipografía y los colores de Rico.
public struct EstadoVacio<Acciones: View>: View {
    private enum Icono {
        case simbolo(String)
        case marca
    }

    private let icono: Icono
    private let titulo: Text
    private let texto: Text
    private let acciones: Acciones

    /// Con un SF Symbol en gris.
    public init(simbolo: String, titulo: Text, texto: Text, @ViewBuilder acciones: () -> Acciones) {
        self.icono = .simbolo(simbolo)
        self.titulo = titulo
        self.texto = texto
        self.acciones = acciones()
    }

    /// Con el símbolo de Rico, para los vacíos de las pestañas.
    public init(marca titulo: Text, texto: Text, @ViewBuilder acciones: () -> Acciones) {
        self.icono = .marca
        self.titulo = titulo
        self.texto = texto
        self.acciones = acciones()
    }

    public var body: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                switch icono {
                case let .simbolo(nombre):
                    Image(systemName: nombre)
                        .font(.rico(.largeTitle, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                        .accessibilityHidden(true)
                case .marca:
                    SimboloRico()
                        .frame(width: 72, height: 72)
                }
                titulo
                    .font(.rico(.title2, peso: .black))
                    .foregroundStyle(Color.ricoTinta)
                    .multilineTextAlignment(.center)
            }
        } description: {
            texto
                .font(.rico(.body, peso: .bold))
                .foregroundStyle(Color.ricoSecundario)
        } actions: {
            acciones
        }
    }
}

public extension EstadoVacio where Acciones == EmptyView {
    init(simbolo: String, titulo: Text, texto: Text) {
        self.init(simbolo: simbolo, titulo: titulo, texto: texto) { EmptyView() }
    }

    init(marca titulo: Text, texto: Text) {
        self.init(marca: titulo, texto: texto) { EmptyView() }
    }
}
