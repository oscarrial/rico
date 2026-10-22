import SwiftUI
import UIKit

/// Botón principal: cápsula tomate a todo el ancho.
public struct BotonPrincipalStyle: ButtonStyle {
    @Environment(\.isEnabled) private var activo

    public init() {}

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let etiqueta = configuration.label
            .font(.rico(.headline, peso: .heavy))
            .foregroundStyle(Color.ricoSobreTomate)
            .frame(maxWidth: .infinity, minHeight: Medidas.alturaBoton)
            .contentShape(Capsule())

        if #available(iOS 26.0, *) {
            // Cristal teñido de tomate: el cristal interactivo ya reacciona al toque.
            etiqueta
                .glassEffect(.regular.tint(.ricoTomate.opacity(activo ? 1 : 0.4)).interactive(activo), in: Capsule())
        } else {
            etiqueta
                .background(Color.ricoTomate.opacity(activo ? 1 : 0.4), in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
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
    let llena: Bool

    /// - Parameter llena: si se coloca en una rejilla, ocupa todo el alto de su fila.
    public init(llena: Bool = false, @ViewBuilder contenido: () -> Contenido) {
        self.contenido = contenido()
        self.llena = llena
    }

    public var body: some View {
        contenido
            .padding(16)
            .frame(
                maxWidth: .infinity,
                maxHeight: llena ? .infinity : nil,
                alignment: llena ? .topLeading : .leading
            )
            .superficieTarjeta()
    }
}

/// Fondo de tarjeta: en claro, sombra cálida y difusa en lugar de borde; en oscuro la sombra no
/// se ve, así que se queda la línea fina (DESIGN.md §5).
private struct SuperficieTarjeta: ViewModifier {
    let radio: CGFloat
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: radio)
        content
            .background(Color.ricoSuperficie, in: forma)
            .clipShape(forma)
            .overlay {
                if esquema == .dark {
                    forma.strokeBorder(Color.ricoLinea)
                }
            }
            .shadow(color: Color(red: 0.35, green: 0.18, blue: 0.08).opacity(esquema == .dark ? 0 : 0.05), radius: 1, y: 1)
            .shadow(color: Color(red: 0.35, green: 0.18, blue: 0.08).opacity(esquema == .dark ? 0 : 0.10), radius: 14, y: 8)
    }
}

public extension View {
    /// Fondo, recorte y elevación de una tarjeta de contenido.
    func superficieTarjeta(radio: CGFloat = Medidas.radioTarjeta) -> some View {
        modifier(SuperficieTarjeta(radio: radio))
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

    @State private var imagen: UIImage?

    public var body: some View {
        Group {
            if let imagen {
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
        .task(id: miniatura) {
            guard let miniatura else {
                imagen = nil
                return
            }
            if let guardada = CacheImagenVisita.cache.object(forKey: miniatura as NSData) {
                imagen = guardada
                return
            }
            let decodificada = await Self.decodificar(miniatura)
            if let decodificada {
                CacheImagenVisita.cache.setObject(decodificada, forKey: miniatura as NSData)
            }
            imagen = decodificada
        }
    }

    /// Decodifica y prepara la imagen fuera del hilo principal.
    nonisolated static func decodificar(_ datos: Data?) async -> UIImage? {
        guard let datos, let imagen = UIImage(data: datos) else { return nil }
        return await imagen.byPreparingForDisplay()
    }
}

@MainActor
private enum CacheImagenVisita {
    static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = 100
        return cache
    }()
}
