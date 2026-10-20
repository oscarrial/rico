import SwiftUI

/// Símbolo de Rico: un tomate cuyo cáliz es la estrella de la nota.
/// Mismas formas que `Brand/simbolo.svg` (lienzo de 100 × 100).
public struct SimboloRico: View {
    public enum Estilo {
        /// Tomate y albahaca.
        case color
        /// Una sola tinta, para fondos de color.
        case monocromo(Color)
    }

    let estilo: Estilo

    public init(estilo: Estilo = .color) {
        self.estilo = estilo
    }

    public var body: some View {
        Canvas { contexto, tamano in
            let escala = min(tamano.width, tamano.height) / 100
            let ajuste = CGAffineTransform(
                translationX: (tamano.width - 100 * escala) / 2,
                y: (tamano.height - 100 * escala) / 2
            ).scaledBy(x: escala, y: escala)

            let cuerpo = FormasRico.cuerpo.applying(ajuste)
            let estrella = FormasRico.estrella.applying(ajuste)
            let tallo = FormasRico.tallo.applying(ajuste)
            let redondeo = StrokeStyle(lineWidth: 3.5 * escala, lineJoin: .round)

            switch estilo {
            case .color:
                contexto.fill(cuerpo, with: .color(.ricoTomate))
                contexto.fill(FormasRico.brillo.applying(ajuste), with: .color(.ricoFondo.opacity(0.55)))
                contexto.fill(estrella, with: .color(.ricoAlbahaca))
                contexto.stroke(estrella, with: .color(.ricoAlbahaca), style: redondeo)
                contexto.stroke(tallo, with: .color(.ricoAlbahaca), style: StrokeStyle(lineWidth: 4.5 * escala, lineCap: .round))
            case let .monocromo(tinta):
                // La estrella se recorta del cuerpo para que se lea a una tinta.
                contexto.fill(cuerpo, with: .color(tinta))
                contexto.blendMode = .destinationOut
                contexto.stroke(estrella, with: .color(.black), style: StrokeStyle(lineWidth: 7 * escala, lineJoin: .round))
                contexto.blendMode = .normal
                contexto.fill(estrella, with: .color(tinta))
                contexto.stroke(estrella, with: .color(tinta), style: redondeo)
                contexto.stroke(tallo, with: .color(tinta), style: StrokeStyle(lineWidth: 4.5 * escala, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Logotipo: «rico» en redondeada pesada.
public struct LogotipoRico: View {
    let tamano: CGFloat

    public init(tamano: CGFloat = 34) {
        self.tamano = tamano
    }

    public var body: some View {
        HStack(alignment: .center, spacing: tamano * 0.18) {
            SimboloRico()
                .frame(width: tamano * 1.1, height: tamano * 1.1)
            Text(verbatim: "rico")
                .font(.system(size: tamano, weight: .black, design: .rounded))
                .tracking(-tamano * 0.03)
                .foregroundStyle(Color.ricoTinta)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Rico"))
    }
}

enum FormasRico {
    static let cuerpo: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 30))
        p.addCurve(to: CGPoint(x: 90, y: 61), control1: CGPoint(x: 73, y: 25), control2: CGPoint(x: 91, y: 40))
        p.addCurve(to: CGPoint(x: 50, y: 93), control1: CGPoint(x: 89, y: 81), control2: CGPoint(x: 71, y: 93))
        p.addCurve(to: CGPoint(x: 10, y: 61), control1: CGPoint(x: 29, y: 93), control2: CGPoint(x: 11, y: 81))
        p.addCurve(to: CGPoint(x: 50, y: 30), control1: CGPoint(x: 9, y: 40), control2: CGPoint(x: 27, y: 25))
        p.closeSubpath()
        return p
    }()

    static let estrella: Path = {
        let puntos: [CGPoint] = [
            CGPoint(x: 50, y: 18), CGPoint(x: 54.4, y: 28.9), CGPoint(x: 66.2, y: 29.8),
            CGPoint(x: 57.1, y: 37.3), CGPoint(x: 60, y: 48.8), CGPoint(x: 50, y: 42.5),
            CGPoint(x: 40, y: 48.8), CGPoint(x: 42.9, y: 37.3), CGPoint(x: 33.8, y: 29.8),
            CGPoint(x: 45.6, y: 28.9)
        ]
        var p = Path()
        p.addLines(puntos)
        p.closeSubpath()
        return p
    }()

    static let tallo: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 22))
        p.addCurve(to: CGPoint(x: 56, y: 8), control1: CGPoint(x: 50, y: 16), control2: CGPoint(x: 52, y: 11))
        return p
    }()

    static let brillo: Path = {
        Path(ellipseIn: CGRect(x: -7, y: -4, width: 14, height: 8))
            .applying(CGAffineTransform(rotationAngle: -35 * .pi / 180))
            .applying(CGAffineTransform(translationX: 29, y: 52))
    }()
}
