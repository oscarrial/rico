import SwiftUI
import StoreKit
import DesignSystem

/// Pantalla de Rico Premium. Se presenta en hoja desde la raíz (`pedirPremium`).
public struct PaywallView: View {
    @Environment(EstadoPremium.self) private var premium
    @Environment(\.dismiss) private var cerrar

    @State private var seleccion: String?
    @State private var error: String?
    @State private var aviso: String?
    @State private var gestionando = false

    static let terminos = URL(string: "https://rico.app/terminos")!
    static let privacidad = URL(string: "https://rico.app/privacidad")!

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    cabecera
                    if premium.esPremium {
                        yaPremium
                    } else {
                        ventajas
                        planes
                    }
                    if let error {
                        mensaje(Text(verbatim: error), simbolo: "exclamationmark.circle", fondo: .ricoTomateSuave, color: .ricoTomateTexto)
                    }
                    if let aviso {
                        mensaje(Text(verbatim: aviso), simbolo: "info.circle", fondo: .ricoSuperficieHundida, color: .ricoTinta)
                    }
                    pie
                }
                .padding(.horizontal, Medidas.margen)
                .padding(.bottom, 24)
            }
            .background(Color.ricoFondo.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { botonPrincipal }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cerrar() } label: {
                        Image(systemName: "xmark")
                            .font(.rico(.body, peso: .bold))
                            .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
                    }
                    .accessibilityLabel(Text("Cerrar", bundle: .module))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.ricoTomate)
        .manageSubscriptionsSheet(isPresented: $gestionando)
        .sensoryFeedback(.selection, trigger: seleccion)
        .task {
            if premium.productos.isEmpty { await premium.cargarProductos() }
            if seleccion == nil { seleccion = premium.anual?.id ?? premium.mensual?.id }
        }
        .onChange(of: premium.productos) { _, productos in
            if seleccion == nil { seleccion = (productos.first { $0.periodo == .anual } ?? productos.first)?.id }
        }
    }

    // MARK: Secciones

    private var cabecera: some View {
        VStack(spacing: 12) {
            SimboloRico()
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)
            Text("Rico Premium", bundle: .module)
                .font(.rico(.largeTitle, peso: .black))
                .foregroundStyle(Color.ricoTinta)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Tu diario, sin límites.", bundle: .module)
                .font(.rico(.body, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var ventajas: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                ventaja("photo.on.rectangle", Text("Fotos ilimitadas en cada visita", bundle: .module))
                ventaja("bookmark", Text("Todas las listas que quieras", bundle: .module))
                ventaja("chart.bar", Text("Las estadísticas de tu año", bundle: .module))
                ventaja("creditcard", Text("Captura automática con Apple Pay", bundle: .module))
                ventaja("square.and.arrow.up", Text("Exporta tu diario cuando quieras", bundle: .module))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ventaja(_ simbolo: String, _ texto: Text) -> some View {
        Label {
            texto
                .font(.rico(.body, peso: .bold))
                .foregroundStyle(Color.ricoTinta)
        } icon: {
            Image(systemName: simbolo)
                .font(.rico(.body, peso: .bold))
                .foregroundStyle(Color.ricoTomate)
                .frame(width: 28)
        }
    }

    @ViewBuilder
    private var planes: some View {
        switch premium.carga {
        case .cargando:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityLabel(Text("Cargando los precios", bundle: .module))
        case .sinProductos:
            VStack(spacing: 12) {
                Text("Ahora mismo no podemos mostrar los precios. Comprueba tu conexión y vuelve a intentarlo en un rato.", bundle: .module)
                    .font(.rico(.body, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await premium.cargarProductos() }
                } label: {
                    Text("Volver a intentarlo", bundle: .module)
                }
                .buttonStyle(.ricoSecundario)
            }
        case .listo:
            VStack(spacing: 10) {
                ForEach(premium.productos) { producto in
                    filaPlan(producto)
                }
                Text("Se renueva solo al mismo precio hasta que lo canceles en Ajustes, como mínimo 24 horas antes de que termine el periodo.", bundle: .module)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private func filaPlan(_ producto: ProductoPremium) -> some View {
        let elegido = seleccion == producto.id
        return Button {
            seleccion = producto.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: elegido ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(elegido ? Color.ricoTomate : Color.ricoSecundario)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        nombrePlan(producto)
                            .font(.rico(.headline, peso: .heavy))
                            .foregroundStyle(Color.ricoTinta)
                        if producto.periodo == .anual, let ahorro = premium.ahorroAnual {
                            Text("Ahorras un \(ahorro) %", bundle: .module)
                                .font(.rico(.caption, peso: .heavy))
                                .foregroundStyle(Color.ricoVerde)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.ricoVerdeSuave, in: Capsule())
                        }
                    }
                    if let dias = producto.diasPrueba, producto.periodo == .anual {
                        Text("\(dias) días gratis, luego \(producto.precioTexto) al año", bundle: .module)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    } else if let dias = producto.diasPrueba {
                        Text("\(dias) días gratis, luego \(producto.precioTexto) al mes", bundle: .module)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    } else if producto.periodo == .anual {
                        Text("\(producto.precioMensualTexto) al mes", bundle: .module)
                            .font(.rico(.subheadline, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                }
                Spacer(minLength: 8)
                precioPlan(producto)
                    .font(.rico(.headline, peso: .black))
                    .foregroundStyle(Color.ricoTinta)
                    .multilineTextAlignment(.trailing)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: Medidas.toqueMinimo)
            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
            .overlay(
                RoundedRectangle(cornerRadius: Medidas.radioTarjeta)
                    .strokeBorder(elegido ? Color.ricoTomate : Color.ricoLinea, lineWidth: elegido ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
    }

    private func nombrePlan(_ producto: ProductoPremium) -> Text {
        switch producto.periodo {
        case .anual: Text("Anual", bundle: .module)
        case .mensual: Text("Mensual", bundle: .module)
        }
    }

    private func precioPlan(_ producto: ProductoPremium) -> Text {
        switch producto.periodo {
        case .anual: Text("\(producto.precioTexto)/año", bundle: .module)
        case .mensual: Text("\(producto.precioTexto)/mes", bundle: .module)
        }
    }

    private var yaPremium: some View {
        VStack(spacing: 14) {
            Label {
                Text("Ya tienes Rico Premium", bundle: .module)
                    .font(.rico(.headline, peso: .heavy))
            } icon: {
                Image(systemName: "checkmark.seal.fill")
            }
            .foregroundStyle(Color.ricoVerde)
            .frame(maxWidth: .infinity, minHeight: Medidas.toqueMinimo)
            .background(Color.ricoVerdeSuave, in: RoundedRectangle(cornerRadius: Medidas.radioControl))

            Text("Fotos sin límite, todas tus listas, las estadísticas de tu año y tu diario para exportar. Gracias por apoyar Rico.", bundle: .module)
                .font(.rico(.body, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
        }
    }

    private var pie: some View {
        VStack(spacing: 8) {
            if !premium.esPremium {
                Button {
                    Task { await restaurar() }
                } label: {
                    Text("Restaurar compras", bundle: .module)
                        .font(.rico(.subheadline, peso: .heavy))
                        .frame(minHeight: Medidas.toqueMinimo)
                }
                .disabled(premium.comprando || premium.restaurando)
            }
            HStack(spacing: 20) {
                Link(destination: Self.terminos) {
                    Text("Términos", bundle: .module)
                        .frame(minHeight: Medidas.toqueMinimo)
                }
                Link(destination: Self.privacidad) {
                    Text("Privacidad", bundle: .module)
                        .frame(minHeight: Medidas.toqueMinimo)
                }
            }
            .font(.rico(.footnote, peso: .bold))
            .foregroundStyle(Color.ricoSecundario)
        }
    }

    private func mensaje(_ texto: Text, simbolo: String, fondo: Color, color: Color) -> some View {
        Label { texto } icon: { Image(systemName: simbolo) }
            .font(.rico(.subheadline, peso: .bold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(fondo, in: RoundedRectangle(cornerRadius: Medidas.radioControl))
    }

    // MARK: Botón principal

    @ViewBuilder
    private var botonPrincipal: some View {
        Group {
            if premium.esPremium {
                Button {
                    gestionando = true
                } label: {
                    Text("Gestionar suscripción", bundle: .module)
                }
            } else {
                Button {
                    Task { await comprar() }
                } label: {
                    if premium.comprando {
                        ProgressView().tint(Color.ricoSobreTomate)
                    } else {
                        Text("Probar Premium", bundle: .module)
                    }
                }
                .disabled(productoElegido == nil || premium.comprando || premium.restaurando)
                .accessibilityLabel(premium.comprando ? Text("Comprando", bundle: .module) : Text("Probar Premium", bundle: .module))
            }
        }
        .buttonStyle(.ricoPrincipal)
        .padding(.horizontal, Medidas.margen)
        .padding(.vertical, 12)
        .fondoBarraInferior()
    }

    private var productoElegido: ProductoPremium? {
        premium.productos.first { $0.id == seleccion }
    }

    // MARK: Acciones

    private func comprar() async {
        guard let producto = productoElegido else { return }
        error = nil
        aviso = nil
        do {
            switch try await premium.comprar(producto) {
            case .comprado:
                if premium.esPremium { cerrar() }
            case .pendiente:
                aviso = String(localized: "Tu compra está pendiente de aprobación. Cuando se apruebe, Premium se activará solo.", bundle: .module)
            case .cancelado:
                break
            }
        } catch {
            self.error = String(localized: "No se pudo completar la compra. No se te ha cobrado nada; prueba de nuevo en un rato.", bundle: .module)
        }
    }

    private func restaurar() async {
        error = nil
        aviso = nil
        do {
            try await premium.restaurar()
            if premium.esPremium {
                cerrar()
            } else {
                aviso = String(localized: "No hemos encontrado compras de Rico Premium con tu cuenta de Apple.", bundle: .module)
            }
        } catch {
            self.error = String(localized: "No se pudieron restaurar las compras. Comprueba tu conexión y prueba de nuevo.", bundle: .module)
        }
    }
}
