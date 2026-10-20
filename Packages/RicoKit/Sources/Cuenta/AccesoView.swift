import AuthenticationServices
import SwiftUI
import DesignSystem

/// Primera pantalla sin sesión: logotipo, promesa y dos formas de entrar.
public struct AccesoView: View {
    @Environment(EstadoCuenta.self) private var cuenta
    @Environment(\.colorScheme) private var esquema

    @State private var nonce = ""
    @State private var entrando = false
    @State private var mostrandoCorreo = false
    @State private var error: ErrorCuenta?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                SimboloRico()
                    .frame(width: 112, height: 112)
                Text(verbatim: "rico")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(Color.ricoTinta)
                    .accessibilityAddTraits(.isHeader)
            }

            Text("Cada restaurante que pruebas, guardado solo.", bundle: .module)
                .font(.rico(.title3, peso: .bold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { peticion in
                    nonce = Nonce.aleatorio()
                    peticion.requestedScopes = [.email]
                    peticion.nonce = Nonce.sha256(nonce)
                } onCompletion: { resultado in
                    gestionarApple(resultado)
                }
                .signInWithAppleButtonStyle(esquema == .dark ? .white : .black)
                .frame(height: Medidas.alturaBoton)
                .clipShape(Capsule())
                .disabled(entrando)

                Button {
                    mostrandoCorreo = true
                } label: {
                    Label {
                        Text("Continuar con correo", bundle: .module)
                    } icon: {
                        Image(systemName: "envelope.fill")
                    }
                }
                .buttonStyle(.ricoSecundario)
                .disabled(entrando)

                if let error = error ?? cuenta.errorEnlace {
                    MensajeError(error: error)
                }

                Text("Al continuar aceptas los [términos](https://rico.app/terminos) y la [política de privacidad](https://rico.app/privacidad).", bundle: .module)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, Medidas.margen)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ricoFondo)
        .overlay {
            if entrando {
                ProgressView()
                    .controlSize(.large)
                    .tint(.ricoTomate)
            }
        }
        .sheet(isPresented: $mostrandoCorreo) {
            AccesoCorreoView()
        }
    }

    private func gestionarApple(_ resultado: Result<ASAuthorization, any Error>) {
        switch resultado {
        case let .success(autorizacion):
            guard let credencial = autorizacion.credential as? ASAuthorizationAppleIDCredential,
                  let datos = credencial.identityToken,
                  let token = String(data: datos, encoding: .utf8)
            else {
                error = .appleSinToken
                return
            }
            let nonceUsado = nonce
            Task {
                entrando = true
                defer { entrando = false }
                do {
                    try await cuenta.iniciarConApple(tokenIdentidad: token, nonce: nonceUsado)
                    error = nil
                } catch let fallo as ErrorCuenta {
                    error = fallo
                } catch {
                    self.error = .otro(error.localizedDescription)
                }
            }
        case let .failure(fallo):
            if (fallo as? ASAuthorizationError)?.code == .canceled { return }
            error = .otro(fallo.localizedDescription)
        }
    }
}

/// Mensaje de error de acceso, en el tono de la app.
struct MensajeError: View {
    let error: ErrorCuenta

    var body: some View {
        texto
            .font(.rico(.footnote, peso: .bold))
            .foregroundStyle(Color.ricoTomateTexto)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.ricoTomateSuave, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
    }

    private var texto: Text {
        switch error {
        case .correoNoValido: Text("Ese correo no parece válido. Revísalo.", bundle: .module)
        case .credencialesIncorrectas: Text("El correo o la contraseña no son correctos.", bundle: .module)
        case .correoSinConfirmar: Text("Antes de entrar, abre el enlace que te enviamos al correo.", bundle: .module)
        case .correoYaRegistrado: Text("Ya hay una cuenta con ese correo. Prueba a entrar.", bundle: .module)
        case .contrasenaDebil: Text("La contraseña necesita al menos 8 caracteres, una letra y un número.", bundle: .module)
        case .enlaceNoValido: Text("El enlace no es válido o ha caducado. Pide otro.", bundle: .module)
        case .sinConexion: Text("No hay conexión. Prueba en un momento.", bundle: .module)
        case .appleSinToken: Text("Apple no ha devuelto tus datos. Vuelve a intentarlo.", bundle: .module)
        case .otro: Text("Algo ha fallado. Vuelve a intentarlo.", bundle: .module)
        }
    }
}
