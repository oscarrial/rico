import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Visitas por valorar: las que llegaron de un pago y las que quedaron a medias.
public struct BandejaPendientesView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(
        filter: #Predicate<Visita> { $0.estadoRaw == "borrador" },
        sort: \Visita.fecha,
        order: .reverse
    )
    private var pendientes: [Visita]

    @State private var ruta: [Paso] = []
    @State private var errorGuardar = false

    enum Paso: Hashable {
        case valorar(Visita)
        case elegirSitio(Visita)
        case guia
    }

    public init() {}

    public var body: some View {
        NavigationStack(path: $ruta) {
            List {
                ForEach(pendientes) { visita in
                    FilaPendiente(
                        visita: visita,
                        alValorar: { ruta.append(.valorar(visita)) },
                        alElegirSitio: { ruta.append(.elegirSitio(visita)) },
                        alDescartar: { descartar(visita) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: Medidas.margen, bottom: 7, trailing: Medidas.margen))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            descartar(visita)
                        } label: {
                            Label { Text("Descartar", bundle: .module) } icon: { Image(systemName: "xmark") }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.ricoFondo)
            .overlay {
                if pendientes.isEmpty { vacio }
            }
            .navigationTitle(Text("Por valorar", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { cerrar() } label: { Text("Listo", bundle: .module) }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: Paso.guia) {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(Text("Cómo guardar tus pagos", bundle: .module))
                }
            }
            .navigationDestination(for: Paso.self) { paso in
                switch paso {
                case let .valorar(visita):
                    FichaRapidaView(modelo: FichaRapidaModelo(visita: visita)) { guardada in
                        confirmar(guardada)
                    }
                case let .elegirSitio(visita):
                    ElegirSitioView(visita: visita) { asignada in
                        // Del buscador se pasa directamente a valorar.
                        ruta = [.valorar(asignada)]
                    }
                case .guia:
                    GuiaAtajoView()
                }
            }
            .alert(Text("No se pudo guardar el cambio", bundle: .module), isPresented: $errorGuardar) {
                Button { } label: { Text("Vale", bundle: .module) }
            }
        }
        .tint(.ricoTomate)
    }

    private var vacio: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                SimboloRico()
                    .frame(width: 64, height: 64)
                Text("Nada por valorar", bundle: .module)
            }
        } description: {
            Text("Cuando pagues con Apple Pay en un restaurante, aparecerá aquí para que lo valores en un momento.", bundle: .module)
        } actions: {
            NavigationLink(value: Paso.guia) {
                Text("Configurar el atajo", bundle: .module)
            }
            .buttonStyle(.ricoPrincipal)
            .padding(.horizontal, 40)
        }
    }

    private func descartar(_ visita: Visita) {
        let id = visita.id
        do {
            try AccionesBandeja.descartar(visita, en: contexto)
            NotificadorLocal().cancelar(visitaID: id)
        } catch {
            contexto.rollback()
            Registro.captura.error("No se pudo descartar: \(String(describing: error), privacy: .public)")
            errorGuardar = true
        }
    }

    private func confirmar(_ visita: Visita) {
        NotificadorLocal().cancelar(visitaID: visita.id)
        do {
            try AccionesBandeja.confirmar(visita, en: contexto)
        } catch {
            Registro.captura.error("No se pudo confirmar el sitio: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Una visita por valorar, con sus acciones.
struct FilaPendiente: View {
    let visita: Visita
    let alValorar: () -> Void
    let alElegirSitio: () -> Void
    let alDescartar: () -> Void

    private var estadoPago: EstadoPago? { visita.pago?.estado }
    private var restaurante: Restaurante? { visita.restaurante }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                icono
                VStack(alignment: .leading, spacing: 3) {
                    titulo
                        .font(.rico(.headline, peso: .heavy))
                        .foregroundStyle(Color.ricoTinta)
                    Text(detalle)
                        .font(.rico(.footnote, peso: .semibold))
                        .foregroundStyle(Color.ricoSecundario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                if restaurante != nil {
                    BotonFila(texto: Text("Valorar", bundle: .module), principal: true, accion: alValorar)
                    if estadoPago == .propuesto {
                        BotonFila(texto: Text("Otro sitio", bundle: .module), principal: false, accion: alElegirSitio)
                    }
                } else {
                    BotonFila(texto: Text("Elegir sitio", bundle: .module), principal: true, accion: alElegirSitio)
                }
            }

            if visita.pago != nil, estadoPago != .asignado {
                Button(action: alDescartar) {
                    Text("No era un restaurante", bundle: .module)
                        .font(.rico(.subheadline, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                        .frame(minHeight: Medidas.toqueMinimo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        .overlay(RoundedRectangle(cornerRadius: Medidas.radioTarjeta).strokeBorder(Color.ricoLinea))
    }

    private var icono: some View {
        Image(systemName: visita.origen == .pago ? "creditcard" : "fork.knife")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.ricoTomateTexto)
            .frame(width: 40, height: 40)
            .background(Color.ricoTomateSuave, in: Circle())
            .accessibilityHidden(true)
    }

    private var titulo: Text {
        if let restaurante {
            if estadoPago == .propuesto {
                return Text("¿Fue en \(restaurante.nombre)?", bundle: .module)
            }
            return Text(restaurante.nombre)
        }
        if let pago = visita.pago {
            return Text(pago.comercioBruto)
        }
        return Text("¿Dónde fue?", bundle: .module)
    }

    private var detalle: String {
        var partes = [FormatoFecha.corta(visita.fecha)]
        if let importe = visita.importe {
            partes.append(importe.textoMoneda)
        }
        if restaurante == nil {
            partes.append(String(localized: "Sin sitio", bundle: .module))
        }
        return partes.joined(separator: " · ")
    }
}

/// Botón en cápsula dentro de una fila. El principal va en tomate suave (no compite con la acción de la pantalla).
struct BotonFila: View {
    let texto: Text
    let principal: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            texto
                .font(.rico(.subheadline, peso: .heavy))
                .foregroundStyle(principal ? Color.ricoTomateTexto : Color.ricoTinta)
                .padding(.horizontal, 18)
                .frame(minHeight: Medidas.toqueMinimo)
                .background(principal ? Color.ricoTomateSuave : Color.ricoSuperficieHundida, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
