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
        /// Lo que hay que tocar, en orden, con los nombres que salen en pantalla.
        let acciones: [String]
        /// Lo que se ve al terminar el paso, para saber que va bien.
        let resultado: String
    }

    private var pasos: [PasoGuia] {
        [
        PasoGuia(
            id: 1,
            simbolo: "plus.circle",
            titulo: String(localized: "Empieza una automatización", bundle: .module),
            acciones: [
                String(localized: "Pulsa el botón «Abrir Atajos» de abajo del todo. Se abre la app Atajos (el icono de cuadrados de colores).", bundle: .module),
                String(localized: "En la barra de abajo de Atajos hay tres pestañas: toca la del centro, «Automatización».", bundle: .module),
                String(localized: "Si no tienes ninguna, toca el botón grande «Nueva automatización». Si ya tienes alguna, toca el + de arriba a la derecha.", bundle: .module)
            ],
            resultado: String(localized: "Ves una lista larga: «Hora del día», «Alarma», «Correo»…", bundle: .module)
        ),
        PasoGuia(
            id: 2,
            simbolo: "wallet.pass",
            titulo: String(localized: "Elige «Transacción»", bundle: .module),
            acciones: [
                String(localized: "Baja por la lista hasta «Transacción» (lleva el icono de la cartera de Wallet) y tócalo.", bundle: .module),
                String(localized: "En «Tarjeta», comprueba que están marcadas las tarjetas con las que pagas. Lo demás, déjalo como está.", bundle: .module),
                String(localized: "Abajo, marca «Ejecutar inmediatamente». Si no, el iPhone te pedirá permiso cada vez que pagues.", bundle: .module),
                String(localized: "Toca «Siguiente», arriba a la derecha.", bundle: .module)
            ],
            resultado: String(localized: "Ves «Nueva automatización en blanco» y unas sugerencias.", bundle: .module)
        ),
        PasoGuia(
            id: 3,
            simbolo: "magnifyingglass",
            titulo: String(localized: "Añade «Registrar pago» de Rico", bundle: .module),
            acciones: [
                String(localized: "Toca «Nueva automatización en blanco».", bundle: .module),
                String(localized: "Toca «Añadir acción» o el buscador de abajo («Buscar apps y acciones»).", bundle: .module),
                String(localized: "Escribe «Rico» y toca «Registrar pago».", bundle: .module)
            ],
            resultado: String(localized: "Ves una caja que dice «Registrar pago en Comercio de Importe», con «Comercio» e «Importe» en azul.", bundle: .module)
        ),
        PasoGuia(
            id: 4,
            simbolo: "hand.tap",
            titulo: String(localized: "Conecta el comercio y el importe", bundle: .module),
            acciones: [
                String(localized: "Toca la palabra azul «Comercio». Encima del teclado sale «Entrada del atajo»: tócalo.", bundle: .module),
                String(localized: "Ahora en su sitio pone «Entrada del atajo». Tócalo otra vez y, en la lista que sale, elige «Comercio».", bundle: .module),
                String(localized: "Haz lo mismo con la palabra azul «Importe»: «Entrada del atajo» y luego «Importe».", bundle: .module),
                String(localized: "Toca «OK», arriba a la derecha.", bundle: .module)
            ],
            resultado: String(localized: "En la caja ya no hay palabras azules sueltas, sino «Comercio» e «Importe» con el icono de Wallet. Ya está: la próxima vez que pagues, Rico lo apunta.", bundle: .module)
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
                    Text("Apple no deja que ninguna app cree automatizaciones por ti: hay que hacerlo una vez a mano en Atajos. Son cuatro pasos y unos dos minutos. Al volver de Atajos sigues aquí, donde lo dejaste.", bundle: .module)
                        .font(.rico(.subheadline, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                    if !esPremium {
                        planGratis
                    }
                    ForEach(pasos) { paso in
                        filaPaso(paso)
                    }
                    siNoFunciona
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
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(verbatim: "\(paso.id)")
                        .font(.rico(.headline, peso: .black))
                        .foregroundStyle(Color.ricoSobreTomate)
                        .frame(width: 34, height: 34)
                        .background(Color.ricoTomate, in: Circle())
                        .accessibilityHidden(true)
                    Text(paso.titulo)
                        .font(.rico(.headline, peso: .heavy))
                        .foregroundStyle(Color.ricoTinta)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel(Text("Paso \(paso.id): \(paso.titulo)", bundle: .module))
                    Spacer(minLength: 0)
                    Image(systemName: paso.simbolo)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ricoTomateTexto)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(paso.acciones.enumerated()), id: \.offset) { indice, accion in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: Self.letra(indice))
                                .font(.rico(.subheadline, peso: .heavy))
                                .foregroundStyle(Color.ricoTomateTexto)
                                .frame(width: 18, alignment: .leading)
                                .accessibilityHidden(true)
                            Text(accion)
                                .font(.rico(.subheadline, peso: .semibold))
                                .foregroundStyle(Color.ricoTinta)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "eye")
                        .foregroundStyle(Color.ricoVerde)
                        .accessibilityHidden(true)
                    Text(paso.resultado)
                        .font(.rico(.footnote, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color.ricoSuperficieHundida, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Lo que verás: \(paso.resultado)", bundle: .module))
            }
        }
    }

    /// «a.», «b.», «c.»… para los toques de cada paso.
    private static func letra(_ indice: Int) -> String {
        let letras = Array("abcdefgh")
        return "\(letras[min(indice, letras.count - 1)])."
    }

    /// Lo que suele fallar, con su arreglo.
    private var siNoFunciona: some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(Text("Si algo no sale", bundle: .module))
            ayuda(
                Text("No aparece Rico al buscar", bundle: .module),
                Text("Abre Rico una vez, ciérralo y vuelve a buscar en Atajos. Si sigue sin salir, reinicia el iPhone.", bundle: .module)
            )
            ayuda(
                Text("No veo «Transacción» en la lista", bundle: .module),
                Text("Hace falta tener una tarjeta en Wallet e iOS 17 o posterior.", bundle: .module)
            )
            ayuda(
                Text("Pagué y no llegó nada", bundle: .module),
                Text("Revisa que marcaste «Ejecutar inmediatamente» y que los avisos de Rico están activados. El aviso llega unos 20 minutos después de pagar, para no molestarte mientras comes.", bundle: .module)
            )
        }
    }

    private func ayuda(_ titulo: Text, _ texto: Text) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            titulo
                .font(.rico(.subheadline, peso: .heavy))
                .foregroundStyle(Color.ricoTinta)
            texto
                .font(.rico(.subheadline, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
