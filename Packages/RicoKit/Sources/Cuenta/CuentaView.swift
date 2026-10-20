import SwiftUI
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
                        Button {
                            cambiandoContrasena = true
                        } label: {
                            Text("Cambiar contraseña", bundle: .module)
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
                NuevaContrasenaView()
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
        } catch let fallo as ErrorCuenta {
            error = fallo
        } catch {
            self.error = .otro(error.localizedDescription)
        }
    }

    private func borrarCuenta() async {
        trabajando = true
        defer { trabajando = false }
        do {
            // Primero el servidor: si falla, el usuario no pierde sus datos locales.
            try await cuenta.borrarCuenta()
            try ContenedorRico.borrarTodo(en: contexto)
            cerrar()
        } catch let fallo as ErrorCuenta {
            error = fallo
        } catch {
            self.error = .otro(error.localizedDescription)
        }
    }
}
