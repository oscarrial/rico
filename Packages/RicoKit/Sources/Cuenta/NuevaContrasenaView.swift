import SwiftUI
import DesignSystem

/// Elegir una contraseña nueva: al abrir el enlace de recuperación o desde «Tu cuenta».
public struct NuevaContrasenaView: View {
    @Environment(EstadoCuenta.self) private var cuenta
    @Environment(\.dismiss) private var cerrar

    public enum Origen: Sendable {
        case recuperacion
        case cuenta
    }

    private let origen: Origen

    @State private var actual = ""
    @State private var contrasena = ""
    @State private var repetida = ""
    @State private var trabajando = false
    @State private var error: ErrorCuenta?
    @State private var hecho = false

    public init(origen: Origen = .recuperacion) {
        self.origen = origen
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if hecho {
                        TarjetaListo()
                    } else {
                        Text("Elige una contraseña nueva para tu cuenta.", bundle: .module)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)

                        if origen == .cuenta {
                            Text("Contraseña actual", bundle: .module)
                                .font(.rico(.footnote, peso: .bold))
                                .foregroundStyle(Color.ricoSecundario)
                            CampoContrasena(texto: $actual, tipo: .password, envio: .next)
                        }

                        CampoContrasena(texto: $contrasena, tipo: .newPassword, envio: .next)
                        ListaReglas(contrasena: contrasena)
                        CampoContrasena(texto: $repetida, tipo: .newPassword, envio: .go)
                        if !repetida.isEmpty, repetida != contrasena {
                            Text("Las contraseñas no coinciden.", bundle: .module)
                                .font(.rico(.footnote, peso: .bold))
                                .foregroundStyle(Color.ricoTomateTexto)
                        }

                        if origen == .cuenta, error == .credencialesIncorrectas {
                            Text("La contraseña actual no es correcta.", bundle: .module)
                                .font(.rico(.footnote, peso: .bold))
                                .foregroundStyle(Color.ricoTomateTexto)
                        } else if let error {
                            MensajeError(error: error)
                        }

                        Button {
                            Task { await guardar() }
                        } label: {
                            if trabajando { ProgressView().tint(.ricoSobreTomate) } else { Text("Guardar contraseña", bundle: .module) }
                        }
                        .buttonStyle(.ricoPrincipal)
                        .disabled(trabajando || !ReglasContrasena.esValida(contrasena) || repetida != contrasena || (origen == .cuenta && actual.isEmpty))
                    }
                }
                .padding(.horizontal, Medidas.margen)
                .padding(.top, 8)
            }
            .background(Color.ricoFondo)
            .navigationTitle(Text("Nueva contraseña", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cuenta.terminarRecuperacion()
                        cerrar()
                    } label: {
                        hecho ? Text("Listo", bundle: .module) : Text("Cancelar", bundle: .module)
                    }
                }
            }
        }
        .tint(.ricoTomate)
    }

    private func guardar() async {
        trabajando = true
        defer { trabajando = false }
        do {
            switch origen {
            case .recuperacion:
                try await cuenta.cambiarContrasena(contrasena)
            case .cuenta:
                try await cuenta.cambiarContrasena(actual: actual, nueva: contrasena)
            }
            error = nil
            hecho = true
        } catch let fallo as ErrorCuenta {
            error = fallo
        } catch {
            self.error = .otro(error.localizedDescription)
        }
    }
}

private struct TarjetaListo: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.ricoVerde)
            Text("Contraseña cambiada. Ya puedes usarla para entrar.", bundle: .module)
                .font(.rico(.subheadline, peso: .bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ricoVerdeSuave, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
    }
}
