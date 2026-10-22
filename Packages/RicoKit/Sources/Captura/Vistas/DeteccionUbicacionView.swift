import SwiftUI
import UIKit
import DesignSystem

/// Activar «¿Has comido en…?» por ubicación. Gratis: no necesita Atajos ni pagar con Apple Pay.
struct DeteccionUbicacionView: View {
    @Environment(\.openURL) private var abrirURL
    private let detector = DetectorEstancias.compartido

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(Text("Lo más fácil: un botón", bundle: .module))
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.ricoTinta)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Detectar comidas por ubicación", bundle: .module)
                                .font(.rico(.headline, peso: .heavy))
                                .foregroundStyle(Color.ricoTinta)
                            Text("Si pasas más de 40 minutos en un restaurante, Rico te pregunta si has comido allí. Sirve aunque pagues en efectivo o invite otro. Gasta muy poca batería.", bundle: .module)
                                .font(.rico(.subheadline, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { detector.activo },
                        set: { $0 ? detector.activar() : detector.desactivar() }
                    )) {
                        Text("Preguntarme al salir", bundle: .module)
                            .font(.rico(.body, peso: .heavy))
                            .foregroundStyle(Color.ricoTinta)
                    }
                    .tint(Color.ricoTomate)
                    .frame(minHeight: Medidas.toqueMinimo)

                    if detector.activo, !detector.vigilando {
                        Text("Para que funcione, la ubicación de Rico tiene que estar en «Siempre».", bundle: .module)
                            .font(.rico(.footnote, peso: .semibold))
                            .foregroundStyle(Color.ricoTomateTexto)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                        } label: {
                            Text("Cambiarlo en Ajustes", bundle: .module)
                        }
                        .buttonStyle(.ricoSecundario)
                    }
                }
            }
        }
    }
}
