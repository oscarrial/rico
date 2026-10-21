import SwiftUI
import UIKit
import DesignSystem

/// Cómo crear en Atajos la automatización que manda a Rico cada pago con Apple Pay,
/// y los permisos que la hacen útil (avisos y ubicación).
public struct GuiaAtajoView: View {
    @Environment(\.openURL) private var abrirURL
    @Environment(\.scenePhase) private var fase
    @Environment(\.esPremium) private var esPremium
    @Environment(\.pedirPremium) private var pedirPremium

    @State private var notificaciones = PermisoNotificaciones()
    @State private var ubicacion = PermisoUbicacion()

    public init() {}

    private struct PasoGuia: Identifiable {
        let id: Int
        let simbolo: String
        let titulo: String
        let texto: String
    }

    private var pasos: [PasoGuia] {
        [
        PasoGuia(
            id: 1,
            simbolo: "square.stack.3d.up",
            titulo: String(localized: "Abre Atajos", bundle: .module),
            texto: String(localized: "Ve a la pestaña Automatización y pulsa «Nueva automatización» o +.", bundle: .module)
        ),
        PasoGuia(
            id: 2,
            simbolo: "wallet.pass",
            titulo: String(localized: "Elige «Transacción»", bundle: .module),
            texto: String(localized: "Está en la sección Wallet. Marca las tarjetas con las que pagas y deja todas las categorías.", bundle: .module)
        ),
        PasoGuia(
            id: 3,
            simbolo: "bolt",
            titulo: String(localized: "Marca «Ejecutar inmediatamente»", bundle: .module),
            texto: String(localized: "Así no tienes que confirmar nada después de pagar.", bundle: .module)
        ),
        PasoGuia(
            id: 4,
            simbolo: "fork.knife",
            titulo: String(localized: "Añade «Registrar pago» de Rico", bundle: .module),
            texto: String(localized: "Pulsa «Nueva automatización en blanco», añade una acción y busca Rico.", bundle: .module)
        ),
        PasoGuia(
            id: 5,
            simbolo: "creditcard",
            titulo: String(localized: "Rellena los datos del pago", bundle: .module),
            texto: String(localized: "Toca cada campo y elige «Entrada del atajo»: Comercio, Importe y Tarjeta.", bundle: .module)
        )
        ]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecera

                if !esPremium {
                    sinPremium
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        TituloSeccion(Text("En la app Atajos", bundle: .module))
                        ForEach(pasos) { paso in
                            filaPaso(paso)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        TituloSeccion(Text("En Rico", bundle: .module))
                        permiso(
                            simbolo: "bell.badge",
                            titulo: Text("Avisos para valorar", bundle: .module),
                            texto: Text("Un rato después de pagar te preguntamos qué tal estuvo.", bundle: .module),
                            estado: notificaciones.estado,
                            boton: Text("Activar avisos", bundle: .module)
                        ) {
                            Task { await notificaciones.pedir() }
                        }
                        permiso(
                            simbolo: "location",
                            titulo: Text("Ubicación al pagar", bundle: .module),
                            texto: Text("Sirve para reconocer el restaurante aunque el pago tenga un nombre raro. Solo se usa en ese momento.", bundle: .module),
                            estado: ubicacion.estado,
                            boton: Text("Permitir ubicación", bundle: .module)
                        ) {
                            ubicacion.pedir()
                        }
                    }
                }
            }
            .padding(.horizontal, Medidas.margen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.ricoFondo)
        .safeAreaInset(edge: .bottom) {
            if esPremium {
                Button {
                    if let url = URL(string: "shortcuts://") { abrirURL(url) }
                } label: {
                    Text("Abrir Atajos", bundle: .module)
                }
                .buttonStyle(.ricoPrincipal)
                .padding(.horizontal, Medidas.margen)
                .padding(.vertical, 12)
                .fondoBarraInferior()
            } else {
                Button {
                    pedirPremium()
                } label: {
                    Text("Probar Premium", bundle: .module)
                }
                .buttonStyle(.ricoPrincipal)
                .padding(.horizontal, Medidas.margen)
                .padding(.vertical, 12)
                .fondoBarraInferior()
            }
        }
        .navigationTitle(Text("Captura automática", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task { await notificaciones.actualizar() }
        .onChange(of: fase) { _, nueva in
            // Al volver de Ajustes o de Atajos.
            if nueva == .active {
                Task { await notificaciones.actualizar() }
            }
        }
    }

    private var sinPremium: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Solo con Rico Premium", bundle: .module)
                } icon: {
                    Image(systemName: "star.circle.fill")
                }
                .font(.rico(.headline, peso: .heavy))
                .foregroundStyle(Color.ricoTomateTexto)
                Text("Cada vez que pagues con Apple Pay en un restaurante, Rico guarda el sitio y el importe y te lo deja listo para valorar en diez segundos. Se configura una vez y funciona solo.", bundle: .module)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paga y Rico se acuerda", bundle: .module)
                .font(.rico(.title, peso: .black))
                .foregroundStyle(Color.ricoTinta)
            Text("Crea una automatización en Atajos una sola vez. Después, cada pago con Apple Pay en un restaurante te espera en Rico para que lo valores.", bundle: .module)
                .font(.rico(.body, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
        }
    }

    private func filaPaso(_ paso: PasoGuia) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: paso.simbolo)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ricoTomateTexto)
                    .frame(width: 48, height: 48)
                    .background(Color.ricoTomateSuave, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                Text(verbatim: "\(paso.id)")
                    .font(.rico(.caption, peso: .heavy))
                    .foregroundStyle(Color.ricoSobreTomate)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Color.ricoTomate, in: Circle())
                    .offset(x: 6, y: 6)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(paso.titulo)
                    .font(.rico(.headline, peso: .heavy))
                    .foregroundStyle(Color.ricoTinta)
                Text(paso.texto)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Paso \(paso.id): \(paso.titulo). \(paso.texto)", bundle: .module))
    }

    private func permiso(
        simbolo: String,
        titulo: Text,
        texto: Text,
        estado: EstadoPermiso,
        boton: Text,
        accion: @escaping () -> Void
    ) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: simbolo)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ricoTinta)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        titulo
                            .font(.rico(.headline, peso: .heavy))
                            .foregroundStyle(Color.ricoTinta)
                        texto
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
                switch estado {
                case .concedido:
                    Label { Text("Activado", bundle: .module) } icon: { Image(systemName: "checkmark.circle.fill") }
                        .font(.rico(.subheadline, peso: .heavy))
                        .foregroundStyle(Color.ricoVerde)
                        .frame(minHeight: Medidas.toqueMinimo)
                case .sinPreguntar:
                    Button(action: accion) { boton }
                        .buttonStyle(.ricoSecundario)
                case .denegado:
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                    } label: {
                        Text("Activarlo en Ajustes", bundle: .module)
                    }
                    .buttonStyle(.ricoSecundario)
                }
            }
        }
    }
}
