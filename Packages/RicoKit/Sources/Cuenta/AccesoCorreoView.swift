import SwiftUI
import DesignSystem

/// Entrar con correo: se envía un código de 6 dígitos y se escribe aquí. Sin contraseñas.
struct AccesoCorreoView: View {
    @Environment(EstadoCuenta.self) private var cuenta
    @Environment(\.dismiss) private var cerrar

    @State private var correo = ""
    @State private var codigo = ""
    @State private var codigoEnviado = false
    @State private var trabajando = false
    @State private var error: ErrorCuenta?
    @FocusState private var foco: Campo?

    enum Campo { case correo, codigo }

    static let longitudCodigo = 6

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if codigoEnviado {
                    pasoCodigo
                } else {
                    pasoCorreo
                }
                if let error {
                    MensajeError(error: error)
                }
                Spacer()
            }
            .padding(.horizontal, Medidas.margen)
            .padding(.top, 12)
            .background(Color.ricoFondo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
                }
            }
            .onAppear { foco = .correo }
        }
        .tint(.ricoTomate)
        .presentationDetents([.medium, .large])
    }

    private var pasoCorreo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("¿Cuál es tu correo?", bundle: .module)
                .font(.rico(.title2, peso: .black))
            Text("Te enviamos un código para entrar. No hace falta contraseña.", bundle: .module)
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
            TextField(text: $correo, prompt: Text("tu@correo.com", bundle: .module)) {
                Text("Correo", bundle: .module)
            }
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .onSubmit { Task { await enviar() } }
            .focused($foco, equals: .correo)
            .modifier(CampoRico())

            Button {
                Task { await enviar() }
            } label: {
                if trabajando { ProgressView().tint(.ricoSobreTomate) } else { Text("Enviar código", bundle: .module) }
            }
            .buttonStyle(.ricoPrincipal)
            .disabled(trabajando || !ValidadorCorreo.esValido(correo.trimmingCharacters(in: .whitespaces)))
        }
    }

    private var pasoCodigo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mira tu correo", bundle: .module)
                .font(.rico(.title2, peso: .black))
            Text("Escribe el código de 6 cifras que hemos enviado a \(correo).", bundle: .module)
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
            TextField(text: $codigo, prompt: Text(verbatim: "000000")) {
                Text("Código", bundle: .module)
            }
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.system(.title, design: .rounded, weight: .black).monospacedDigit())
            .tracking(6)
            .focused($foco, equals: .codigo)
            .modifier(CampoRico())
            .onChange(of: codigo) { _, nuevo in
                let soloCifras = String(nuevo.filter(\.isNumber).prefix(Self.longitudCodigo))
                if soloCifras != nuevo { codigo = soloCifras }
                if soloCifras.count == Self.longitudCodigo { Task { await verificar() } }
            }

            HStack {
                Button {
                    codigoEnviado = false
                    codigo = ""
                    error = nil
                    foco = .correo
                } label: {
                    Text("Cambiar correo", bundle: .module)
                }
                Spacer()
                Button {
                    Task { await enviar() }
                } label: {
                    Text("Reenviar código", bundle: .module)
                }
                .disabled(trabajando)
            }
            .font(.rico(.subheadline, peso: .heavy))
            .frame(minHeight: Medidas.toqueMinimo)

            if trabajando {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func enviar() async {
        guard !trabajando else { return }
        trabajando = true
        defer { trabajando = false }
        do {
            try await cuenta.enviarCodigo(a: correo)
            error = nil
            codigoEnviado = true
            foco = .codigo
        } catch let fallo as ErrorCuenta {
            error = fallo
        } catch {
            self.error = .otro(error.localizedDescription)
        }
    }

    private func verificar() async {
        guard !trabajando else { return }
        trabajando = true
        defer { trabajando = false }
        do {
            try await cuenta.verificarCodigo(codigo, correo: correo)
            error = nil
            cerrar()
        } catch let fallo as ErrorCuenta {
            error = fallo
            codigo = ""
        } catch {
            self.error = .otro(error.localizedDescription)
        }
    }
}

/// Campo de texto con el aspecto de las tarjetas.
struct CampoRico: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.rico(.body, peso: .bold))
            .padding(.horizontal, 16)
            .frame(minHeight: Medidas.alturaBoton)
            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
            .overlay(RoundedRectangle(cornerRadius: Medidas.radioControl).strokeBorder(Color.ricoLinea))
    }
}
