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
    @State private var pruebaEnviada = false

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
            simbolo: "plus.circle",
            titulo: String(localized: "Crea una automatización", bundle: .module),
            texto: String(localized: "Pulsa «Abrir Atajos» (abajo). Toca «Automatización» en la barra de abajo y luego el + de arriba a la derecha.", bundle: .module)
        ),
        PasoGuia(
            id: 2,
            simbolo: "wallet.pass",
            titulo: String(localized: "Toca «Transacción»", bundle: .module),
            texto: String(localized: "Baja hasta encontrarla. Deja marcadas tus tarjetas, elige «Ejecutar inmediatamente» y toca «Siguiente».", bundle: .module)
        ),
        PasoGuia(
            id: 3,
            simbolo: "magnifyingglass",
            titulo: String(localized: "Añade la acción de Rico", bundle: .module),
            texto: String(localized: "Toca «Nueva automatización en blanco» y «Añadir acción». Escribe «Rico» y toca «Registrar pago».", bundle: .module)
        ),
        PasoGuia(
            id: 4,
            simbolo: "hand.tap",
            titulo: String(localized: "Conecta el comercio y el importe", bundle: .module),
            texto: String(localized: "En la acción salen «Comercio» e «Importe» en azul. Toca cada uno, elige «Entrada del atajo» y después «Comercio» o «Importe». Toca «OK» y listo.", bundle: .module)
        )
        ]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecera

                // Lo de un solo botón va primero; Atajos es para quien quiera afinar más.
                DeteccionUbicacionView()

                VStack(alignment: .leading, spacing: 14) {
                    TituloSeccion(Text("Con Apple Pay, más exacto", bundle: .module))
                    Text("Apple no deja que ninguna app cree automatizaciones por ti: hay que hacerlo una vez a mano en Atajos. Son cuatro pasos y un minuto.", bundle: .module)
                        .font(.rico(.subheadline, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                    if !esPremium {
                        planGratis
                    }
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
                    if notificaciones.estado == .concedido {
                        Button {
                            pruebaEnviada = true
                            Task { await NotificadorLocal().probar() }
                        } label: {
                            Label {
                                Text("Enviar un aviso de prueba", bundle: .module)
                            } icon: {
                                Image(systemName: "bell")
                            }
                        }
                        .buttonStyle(.ricoSecundario)
                        if pruebaEnviada {
                            Text("Te llegará en unos segundos.", bundle: .module)
                                .font(.rico(.footnote, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                        }
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
            .padding(.horizontal, Medidas.margen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.ricoFondo)
        .safeAreaInset(edge: .bottom) {
            Button {
                if let url = URL(string: "shortcuts://") { abrirURL(url) }
            } label: {
                Text("Abrir Atajos", bundle: .module)
            }
            .buttonStyle(.ricoPrincipal)
            .padding(.horizontal, Medidas.margen)
            .padding(.vertical, 12)
            .fondoBarraInferior()
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

    /// Plan gratis: una captura al mes para probarla; con Premium, todas.
    private var planGratis: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Plan gratis: 1 captura al mes", bundle: .module)
                } icon: {
                    Image(systemName: "creditcard")
                }
                .font(.rico(.headline, peso: .heavy))
                .foregroundStyle(Color.ricoTinta)
                Text("Pruébala con tu próxima comida. Con Rico Premium, cada pago en un restaurante se guarda solo, sin límite.", bundle: .module)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
                Button {
                    pedirPremium()
                } label: {
                    Text("Ver Rico Premium", bundle: .module)
                        .font(.rico(.subheadline, peso: .heavy))
                        .foregroundStyle(Color.ricoTomateTexto)
                        .frame(minHeight: Medidas.toqueMinimo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paga y Rico se acuerda", bundle: .module)
                .font(.rico(.title, peso: .black))
                .foregroundStyle(Color.ricoTinta)
            Text("Rico te pregunta «¿qué tal?» después de comer fuera, sin que tengas que apuntar nada.", bundle: .module)
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
