import SwiftUI
import RicoCore

/// Nota de solo lectura con medias estrellas.
public struct EstrellasView: View {
    let nota: Double
    let tamano: CGFloat

    public init(nota: Double, tamano: CGFloat = 14) {
        self.nota = nota
        self.tamano = tamano
    }

    public var body: some View {
        HStack(spacing: tamano * 0.12) {
            ForEach(1...5, id: \.self) { n in
                Image(systemName: simbolo(n))
                    .font(.system(size: tamano))
                    .foregroundStyle(Estrellas.relleno(estrella: n, nota: nota) > 0 ? Color.ricoEstrella : Color.ricoEstrellaVacia)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(NotaTexto.texto(nota)) de 5 estrellas", bundle: .module))
    }

    private func simbolo(_ n: Int) -> String {
        switch Estrellas.relleno(estrella: n, nota: nota) {
        case 1: "star.fill"
        case 0.5: "star.leadinghalf.filled"
        default: "star.fill"
        }
    }
}

/// Nota compacta «★ 4,5».
public struct NotaCompacta: View {
    let nota: Double

    public init(nota: Double) {
        self.nota = nota
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.ricoEstrella)
                .accessibilityHidden(true)
            Text(NotaTexto.texto(nota))
        }
        .font(.rico(.subheadline, peso: .heavy))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(NotaTexto.texto(nota)) de 5 estrellas", bundle: .module))
    }
}

/// Selector de nota: tocar una estrella pone esa nota; tocarla otra vez deja media menos.
/// Con VoiceOver se ajusta deslizando arriba y abajo en pasos de media estrella.
public struct SelectorEstrellas: View {
    @Binding var nota: Double
    let tamano: CGFloat

    public init(nota: Binding<Double>, tamano: CGFloat = 44) {
        self._nota = nota
        self.tamano = tamano
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    nota = Estrellas.alTocar(estrella: n, actual: nota)
                } label: {
                    Image(systemName: simbolo(n))
                        .font(.system(size: tamano))
                        .foregroundStyle(Estrellas.relleno(estrella: n, nota: nota) > 0 ? Color.ricoEstrella : Color.ricoEstrellaVacia)
                        .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: nota)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Nota", bundle: .module))
        .accessibilityValue(nota == 0
            ? Text("Sin valorar", bundle: .module)
            : Text("\(NotaTexto.texto(nota)) de 5 estrellas", bundle: .module))
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: nota = min(Estrellas.maximo, max(Estrellas.minimo, nota + 0.5))
            case .decrement: nota = max(Estrellas.minimo, nota - 0.5)
            @unknown default: break
            }
        }
    }

    private func simbolo(_ n: Int) -> String {
        Estrellas.relleno(estrella: n, nota: nota) == 0.5 ? "star.leadinghalf.filled" : "star.fill"
    }
}

public enum NotaTexto {
    /// «4,5», «4», según el idioma del usuario.
    public static func texto(_ nota: Double) -> String {
        nota.formatted(.number.precision(.fractionLength(0...1)))
    }
}
