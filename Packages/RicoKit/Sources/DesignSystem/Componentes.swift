import SwiftUI
import UIKit

/// Botón principal: cápsula tomate a todo el ancho.
public struct BotonPrincipalStyle: ButtonStyle {
    @Environment(\.isEnabled) private var activo

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rico(.headline, peso: .heavy))
            .foregroundStyle(Color.ricoSobreTomate)
            .frame(maxWidth: .infinity, minHeight: Medidas.alturaBoton)
            .background(Color.ricoTomate.opacity(activo ? 1 : 0.4), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Botón secundario: cápsula con borde.
public struct BotonSecundarioStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rico(.headline, peso: .heavy))
            .foregroundStyle(Color.ricoTinta)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.ricoSuperficie, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.ricoLinea, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

public extension ButtonStyle where Self == BotonPrincipalStyle {
    static var ricoPrincipal: BotonPrincipalStyle { BotonPrincipalStyle() }
}

public extension ButtonStyle where Self == BotonSecundarioStyle {
    static var ricoSecundario: BotonSecundarioStyle { BotonSecundarioStyle() }
}

/// Grupo de opciones excluyentes con aspecto de pastillas («Sí / Quizá / No»).
public struct Pastillas<Valor: Hashable>: View {
    let opciones: [(valor: Valor, titulo: Text)]
    @Binding var seleccion: Valor?
    let altura: CGFloat

    public init(opciones: [(valor: Valor, titulo: Text)], seleccion: Binding<Valor?>, altura: CGFloat = Medidas.toqueMinimo) {
        self.opciones = opciones
        self._seleccion = seleccion
        self.altura = altura
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(opciones.indices, id: \.self) { i in
                let opcion = opciones[i]
                let activa = seleccion == opcion.valor
                Button {
                    seleccion = activa ? nil : opcion.valor
                } label: {
                    opcion.titulo
                        .font(.rico(altura >= Medidas.toqueMinimo ? .subheadline : .footnote, peso: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: altura)
                        .foregroundStyle(activa ? Color.ricoSobreTomate : Color.ricoTinta)
                        .background(activa ? Color.ricoTomate : Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(activa ? Color.ricoTomate : Color.ricoLinea, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activa ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: seleccion)
    }
}

/// Tarjeta blanca con borde suave.
public struct Tarjeta<Contenido: View>: View {
    let contenido: Contenido

    public init(@ViewBuilder contenido: () -> Contenido) {
        self.contenido = contenido()
    }

    public var body: some View {
        contenido
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
            .overlay(RoundedRectangle(cornerRadius: Medidas.radioTarjeta).strokeBorder(Color.ricoLinea))
    }
}

/// Título de sección en versalitas.
public struct TituloSeccion: View {
    let texto: Text

    public init(_ texto: Text) {
        self.texto = texto
    }

    public var body: some View {
        texto
            .font(.rico(.footnote, peso: .heavy))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Color.ricoSecundario)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Imagen de una foto guardada o, si no hay, un bloque de color estable para ese id.
public struct ImagenVisita: View {
    let miniatura: Data?
    let semilla: Int

    public init(miniatura: Data?, semilla: Int) {
        self.miniatura = miniatura
        self.semilla = semilla
    }

    public var body: some View {
        if let miniatura, let imagen = UIImage(data: miniatura) {
            Image(uiImage: imagen)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            let colores = Color.ricoPlaceholders
            colores[abs(semilla) % colores.count]
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .accessibilityHidden(true)
        }
    }
}
