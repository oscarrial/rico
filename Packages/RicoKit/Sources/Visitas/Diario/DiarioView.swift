import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore

/// Línea de tiempo: todas las visitas valoradas, de la más reciente a la más antigua.
public struct DiarioView<Cabecera: View>: View {
    @Query(
        filter: #Predicate<Visita> { $0.estadoRaw == "valorada" },
        sort: \Visita.fecha,
        order: .reverse
    )
    private var visitas: [Visita]

    @State private var busqueda = ""
    @State private var mostrandoAlta = false

    private let alAbrirCuenta: (() -> Void)?
    private let cabecera: Cabecera

    /// - Parameters:
    ///   - alAbrirCuenta: si se pasa, aparece el botón de cuenta arriba a la derecha.
    ///   - cabecera: lo que va encima de las visitas (el aviso de pendientes).
    public init(alAbrirCuenta: (() -> Void)? = nil, @ViewBuilder cabecera: () -> Cabecera) {
        self.alAbrirCuenta = alAbrirCuenta
        self.cabecera = cabecera()
    }

    public var body: some View {
        let secciones = AgrupadorDiario.secciones(AgrupadorDiario.filtrar(visitas, busqueda: busqueda))
        return NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if busqueda.isEmpty {
                        cabecera
                    }
                    if busqueda.isEmpty, !visitas.isEmpty {
                        resumenMes
                    }
                    ForEach(secciones, id: \.titulo) { seccion in
                        TituloSeccion(Text(seccion.titulo))
                            .padding(.top, 8)
                        ForEach(seccion.visitas) { visita in
                            if let restaurante = visita.restaurante {
                                NavigationLink(value: restaurante) {
                                    TarjetaVisitaView(visita: visita)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Medidas.margen)
                .padding(.bottom, 100)
            }
            .background(Color.ricoFondo)
            .overlay {
                if visitas.isEmpty {
                    vacio
                } else if secciones.isEmpty {
                    ContentUnavailableView.search(text: busqueda)
                }
            }
            .overlay(alignment: .bottomTrailing) { botonAnadir }
            .navigationTitle(Text("Diario", bundle: .module))
            .searchable(text: $busqueda, prompt: Text("Sitio, ciudad o plato", bundle: .module))
            .toolbar {
                if let alAbrirCuenta {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: alAbrirCuenta) {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel(Text("Tu cuenta", bundle: .module))
                    }
                }
            }
            .navigationDestination(for: Restaurante.self) { restaurante in
                FichaRestauranteView(restaurante: restaurante)
            }
            .sheet(isPresented: $mostrandoAlta) {
                AltaManualView()
            }
        }
    }

    // MARK: Vistas

    private var resumenMes: some View {
        let mes = AgrupadorDiario.resumenMes(visitas)
        let gasto = mes.gasto.textoMoneda
        return Text("Este mes: ^[\(mes.visitas) visita](inflect: true) · \(gasto)", bundle: .module)
            .font(.rico(.subheadline, peso: .semibold))
            .foregroundStyle(Color.ricoSecundario)
    }

    private var vacio: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                SimboloRico()
                    .frame(width: 72, height: 72)
                Text("Tu diario está vacío", bundle: .module)
            }
        } description: {
            Text("Pulsa + para guardar el primer sitio donde has comido.", bundle: .module)
        }
    }

    private var botonAnadir: some View {
        BotonFlotante(simbolo: "plus", etiqueta: Text("Añadir visita", bundle: .module)) {
            mostrandoAlta = true
        }
        .padding(.trailing, Medidas.margen)
        .padding(.bottom, 16)
    }
}

public extension DiarioView where Cabecera == EmptyView {
    init(alAbrirCuenta: (() -> Void)? = nil) {
        self.init(alAbrirCuenta: alAbrirCuenta) { EmptyView() }
    }
}

/// Tarjeta de una visita en el diario.
struct TarjetaVisitaView: View {
    let visita: Visita

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ImagenVisita(miniatura: visita.fotosOrdenadas.first?.miniatura, semilla: visita.id.semilla)
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if let plato = visita.platosOrdenados.first(where: { $0.valoracion == .encanto }) ?? visita.platosOrdenados.first {
                        Text(plato.nombre)
                            .font(.rico(.caption, peso: .heavy))
                            .foregroundStyle(Color.ricoTinta)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.ricoSuperficie, in: Capsule())
                            .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Text(FormatoFecha.corta(visita.fecha))
                        .font(.rico(.caption, peso: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(visita.restaurante?.nombre ?? "")
                        .font(.rico(.headline, peso: .heavy))
                        .foregroundStyle(Color.ricoTinta)
                    Spacer()
                    if let estrellas = visita.estrellas {
                        NotaCompacta(nota: estrellas)
                            .foregroundStyle(Color.ricoTinta)
                    }
                }
                Text(detalle)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.ricoSuperficie)
        .clipShape(RoundedRectangle(cornerRadius: Medidas.radioTarjeta))
        .overlay(RoundedRectangle(cornerRadius: Medidas.radioTarjeta).strokeBorder(Color.ricoLinea))
        .accessibilityElement(children: .combine)
    }

    private var detalle: String {
        var partes: [String] = []
        if let ciudad = visita.restaurante?.ciudad { partes.append(ciudad) }
        if let porPersona = visita.importePorPersona {
            partes.append(String(localized: "\(porPersona.textoMoneda) por persona", bundle: .module))
        }
        switch visita.volveria {
        case .si: partes.append(String(localized: "Volvería", bundle: .module))
        case .no: partes.append(String(localized: "No volvería", bundle: .module))
        case .quiza, nil: break
        }
        return partes.joined(separator: " · ")
    }
}
