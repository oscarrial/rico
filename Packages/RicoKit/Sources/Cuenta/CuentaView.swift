import AuthenticationServices
import SwiftUI
import UIKit
import SwiftData
import DesignSystem
import Modelos

/// «Tu cuenta»: correo, cerrar sesión y borrar la cuenta (obligatorio en la App Store).
public struct CuentaView: View {
    @Environment(EstadoCuenta.self) private var cuenta
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var confirmandoBorrado = false
    @State private var cambiandoContrasena = false
    @State private var trabajando = false
    @State private var error: ErrorCuenta?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent {
                        Text(verbatim: cuenta.sesion?.correo ?? "—")
                    } label: {
                        Text("Correo", bundle: .module)
                    }
                    if cuenta.fase == .soloLocal {
                        Text("Sin cuenta: tus datos solo están en este iPhone.", bundle: .module)
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }

                if cuenta.sesion != nil {
                    Section {
                        if cuenta.sesion?.proveedor == "email" {
                            Button {
                                cambiandoContrasena = true
                            } label: {
                                Text("Cambiar contraseña", bundle: .module)
                            }
                        }
                        Button {
                            Task { await cerrarSesion() }
                        } label: {
                            Text("Cerrar sesión", bundle: .module)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            confirmandoBorrado = true
                        } label: {
                            Text("Borrar mi cuenta", bundle: .module)
                        }
                    } footer: {
                        Text("Se borran para siempre tu cuenta, tus visitas, tus fotos y tus listas, en este iPhone y en nuestro servidor.", bundle: .module)
                    }
                }

                if let error {
                    Section {
                        MensajeError(error: error)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .font(.rico(.body, peso: .semibold))
            .scrollContentBackground(.hidden)
            .background(Color.ricoFondo)
            .navigationTitle(Text("Tu cuenta", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { cerrar() } label: { Text("Listo", bundle: .module) }
                }
            }
            .disabled(trabajando)
            .overlay { if trabajando { ProgressView().controlSize(.large) } }
            .sheet(isPresented: $cambiandoContrasena) {
                NuevaContrasenaView(origen: .cuenta)
            }
            .confirmationDialog(
                Text("¿Borrar tu cuenta?", bundle: .module),
                isPresented: $confirmandoBorrado,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    Task { await borrarCuenta() }
                } label: {
                    Text("Borrar todo", bundle: .module)
                }
            } message: {
                Text("No se puede deshacer.", bundle: .module)
            }
        }
        .tint(.ricoTomate)
    }

    private func cerrarSesion() async {
        trabajando = true
        defer { trabajando = false }
        do {
            try await cuenta.cerrarSesion()
            cerrar()
        } catch {
            self.error = error as? ErrorCuenta ?? .otro("")
        }
    }

    private func borrarCuenta() async {
        trabajando = true
        defer { trabajando = false }
        error = nil

        // Con Apple hay que pedir una autorización nueva: su código permite revocar el acceso.
        var codigoApple: String?
        if cuenta.sesion?.proveedor == "apple" {
            switch await PeticionCodigoApple().pedir() {
            case let .codigo(codigo): codigoApple = codigo
            case .cancelado: return
            case .fallo: codigoApple = nil
            }
        }

        do {
            // Primero el servidor; si falla, el usuario no pierde sus datos locales.
            // Después se vacía el iPhone antes de cerrar sesión, y si eso falla queda anotado.
            try await cuenta.borrarCuenta(codigoApple: codigoApple) {
                try ContenedorRico.borrarTodo(en: contexto)
            }
            cerrar()
        } catch {
            self.error = error as? ErrorCuenta ?? .otro("")
        }
    }
}

/// Pide a Apple una autorización nueva (sin ámbitos) y devuelve su `authorizationCode`.
@MainActor
private final class PeticionCodigoApple: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    enum Resultado: Sendable {
        case codigo(String)
        case cancelado
        case fallo
    }

    private var continuacion: CheckedContinuation<Resultado, Never>?
    private var controlador: ASAuthorizationController?

    func pedir() async -> Resultado {
        await withCheckedContinuation { continuacion in
            self.continuacion = continuacion
            let controlador = ASAuthorizationController(
                authorizationRequests: [ASAuthorizationAppleIDProvider().createRequest()]
            )
            controlador.delegate = self
            controlador.presentationContextProvider = self
            self.controlador = controlador
            controlador.performRequests()
        }
    }

    private func terminar(_ resultado: Resultado) {
        continuacion?.resume(returning: resultado)
        continuacion = nil
        controlador = nil
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let codigo = (authorization.credential as? ASAuthorizationAppleIDCredential)?
            .authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            self.terminar(codigo.map(Resultado.codigo) ?? .fallo)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        let cancelado = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            self.terminar(cancelado ? .cancelado : .fallo)
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let ventanas = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            return ventanas.first(where: \.isKeyWindow) ?? ventanas.first ?? ASPresentationAnchor()
        }
    }
}
