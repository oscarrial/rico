import SwiftUI
import DesignSystem

/// Entrar o crear cuenta con correo y contraseña.
struct AccesoCorreoView: View {
    enum Modo: Hashable {
        case entrar
        case crear
    }

    @Environment(EstadoCuenta.self) private var cuenta
    @Environment(\.dismiss) private var cerrar

    @State private var modo: Modo = .entrar
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var repetida = ""
    @State private var trabajando = false
    @State private var error: ErrorCuenta?
    @State private var aviso: Aviso?
    @FocusState private var foco: Campo?

    enum Campo { case correo, contrasena, repetida }

    /// Mensajes que no son errores: «revisa tu correo».
    enum Aviso: Equatable {
        case confirmaTuCorreo(String)
        case recuperacionEnviada(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker(selection: $modo) {
                        Text("Entrar", bundle: .module).tag(Modo.entrar)
                        Text("Crear cuenta", bundle: .module).tag(Modo.crear)
                    } label: {
                        Text("Modo", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: modo) { _, _ in
                        error = nil
                    }

                    if let aviso {
                        TarjetaAviso(aviso: aviso)
                    }

                    campos

                    if let error {
                        MensajeError(error: error)
                    }

                    Button {
                        Task { await continuar() }
                    } label: {
                        if trabajando {
                            ProgressView().tint(.ricoSobreTomate)
                        } else if modo == .entrar {
                            Text("Entrar", bundle: .module)
                        } else {
                            Text("Crear cuenta", bundle: .module)
                        }
                    }
                    .buttonStyle(.ricoPrincipal)
                    .disabled(trabajando || !puedeContinuar)

                    if modo == .entrar {
                        Button {
                            Task { await recuperar() }
                        } label: {
                            Text("¿Has olvidado tu contraseña?", bundle: .module)
                                .font(.rico(.subheadline, peso: .heavy))
                                .frame(maxWidth: .infinity, minHeight: Medidas.toqueMinimo)
                        }
                        .disabled(trabajando)
                    }
                }
                .padding(.horizontal, Medidas.margen)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ricoFondo)
            .navigationTitle(modo == .entrar ? Text("Entrar con correo", bundle: .module) : Text("Crear cuenta", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
                }
            }
            .onAppear { foco = .correo }
        }
        .tint(.ricoTomate)
    }

    // MARK: Campos

    @ViewBuilder
    private var campos: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Correo", bundle: .module)
                .font(.rico(.footnote, peso: .heavy))
                .foregroundStyle(Color.ricoSecundario)
            TextField(text: $correo, prompt: Text("tu@correo.com", bundle: .module)) {
                Text("Correo", bundle: .module)
            }
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit { foco = .contrasena }
            .focused($foco, equals: .correo)
            .modifier(CampoRico())
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Contraseña", bundle: .module)
                .font(.rico(.footnote, peso: .heavy))
                .foregroundStyle(Color.ricoSecundario)
            CampoContrasena(
                texto: $contrasena,
                tipo: modo == .crear ? .newPassword : .password,
                envio: modo == .crear ? .next : .go
            )
            .focused($foco, equals: .contrasena)
            .onSubmit {
                if modo == .crear { foco = .repetida } else { Task { await continuar() } }
            }
        }

        if modo == .crear {
            ListaReglas(contrasena: contrasena)

            VStack(alignment: .leading, spacing: 6) {
                Text("Repite la contraseña", bundle: .module)
                    .font(.rico(.footnote, peso: .heavy))
                    .foregroundStyle(Color.ricoSecundario)
                CampoContrasena(texto: $repetida, tipo: .newPassword, envio: .go)
                    .focused($foco, equals: .repetida)
                    .onSubmit { Task { await continuar() } }
                if !repetida.isEmpty, repetida != contrasena {
                    Text("Las contraseñas no coinciden.", bundle: .module)
                        .font(.rico(.footnote, peso: .bold))
                        .foregroundStyle(Color.ricoTomateTexto)
                }
            }
        }
    }

    private var correoValido: Bool {
        ValidadorCorreo.esValido(ValidadorCorreo.normalizar(correo))
    }

    private var puedeContinuar: Bool {
        switch modo {
        case .entrar:
            correoValido && !contrasena.isEmpty
        case .crear:
            correoValido && ReglasContrasena.esValida(contrasena) && repetida == contrasena
        }
    }

    // MARK: Acciones

    private func continuar() async {
        guard puedeContinuar, !trabajando else { return }
        trabajando = true
        defer { trabajando = false }
        error = nil
        aviso = nil
        do {
            switch modo {
            case .entrar:
                try await cuenta.iniciarSesion(correo: correo, contrasena: contrasena)
                cerrar()
            case .crear:
                switch try await cuenta.registrar(correo: correo, contrasena: contrasena) {
                case .sesionIniciada:
                    cerrar()
                case .confirmaTuCorreo:
                    // Tras confirmar, entrará con lo que ya ha escrito.
                    modo = .entrar
                    aviso = .confirmaTuCorreo(ValidadorCorreo.normalizar(correo))
                    repetida = ""
                }
            }
        } catch {
            self.error = error as? ErrorCuenta ?? .otro("")
        }
    }

    private func recuperar() async {
        guard correoValido else {
            error = .correoNoValido
            foco = .correo
            return
        }
        trabajando = true
        defer { trabajando = false }
        do {
            try await cuenta.enviarRecuperacion(a: correo)
            error = nil
            aviso = .recuperacionEnviada(ValidadorCorreo.normalizar(correo))
        } catch {
            self.error = error as? ErrorCuenta ?? .otro("")
        }
    }
}

/// Campo de contraseña con botón para mostrarla. Respeta el autorrelleno del llavero.
struct CampoContrasena: View {
    @Binding var texto: String
    let tipo: UITextContentType
    let envio: SubmitLabel

    @State private var visible = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if visible {
                    TextField(text: $texto) { Text("Contraseña", bundle: .module) }
                } else {
                    SecureField(text: $texto) { Text("Contraseña", bundle: .module) }
                }
            }
            .textContentType(tipo)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(envio)

            Button {
                visible.toggle()
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .foregroundStyle(Color.ricoSecundario)
                    .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(visible ? Text("Ocultar contraseña", bundle: .module) : Text("Mostrar contraseña", bundle: .module))
        }
        .modifier(CampoRico())
    }
}

/// Reglas de la contraseña, marcadas según se cumplen.
struct ListaReglas: View {
    let contrasena: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ReglasContrasena.Regla.allCases, id: \.self) { regla in
                let cumple = ReglasContrasena.cumple(regla, contrasena)
                HStack(spacing: 6) {
                    Image(systemName: cumple ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(cumple ? Color.ricoVerde : Color.ricoSecundario)
                    texto(regla)
                        .foregroundStyle(cumple ? Color.ricoTinta : Color.ricoSecundario)
                }
                .font(.rico(.footnote, peso: .bold))
                .accessibilityElement(children: .combine)
                .accessibilityValue(cumple ? Text("cumplida", bundle: .module) : Text("pendiente", bundle: .module))
            }
        }
        .animation(.snappy(duration: 0.2), value: contrasena)
    }

    private func texto(_ regla: ReglasContrasena.Regla) -> Text {
        switch regla {
        case .longitud: Text("Al menos \(ReglasContrasena.longitudMinima) caracteres", bundle: .module)
        case .letra: Text("Una letra", bundle: .module)
        case .numero: Text("Un número", bundle: .module)
        }
    }
}

/// Aviso de «mira tu correo».
struct TarjetaAviso: View {
    let aviso: AccesoCorreoView.Aviso

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "envelope.badge")
                .font(.title3)
                .foregroundStyle(Color.ricoVerde)
            texto
                .font(.rico(.subheadline, peso: .bold))
                .foregroundStyle(Color.ricoTinta)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ricoVerdeSuave, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
    }

    private var texto: Text {
        switch aviso {
        case let .confirmaTuCorreo(correo):
            Text("Te hemos enviado un enlace a \(correo). Ábrelo en este iPhone para activar la cuenta.", bundle: .module)
        case let .recuperacionEnviada(correo):
            Text("Si hay una cuenta con \(correo), te llegará un enlace para elegir una contraseña nueva.", bundle: .module)
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
