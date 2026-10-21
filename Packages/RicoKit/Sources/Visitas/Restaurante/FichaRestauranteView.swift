import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import RicoCore

/// Todas tus visitas a un sitio, nota media, gasto medio y platos que pediste.
public struct FichaRestauranteView: View {
    let restaurante: Restaurante

    @State private var visitaEditada: Visita?
    @State private var nuevaVisita = false
    @State private var guardandoEnLista = false

    public init(restaurante: Restaurante) {
        self.restaurante = restaurante
    }

    public var body: some View {
        let resumen = ResumenRestaurante(restaurante: restaurante)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ImagenVisita(miniatura: resumen.fotoPortada, semilla: restaurante.id.semilla)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(restaurante.nombre)
                            .font(.rico(.largeTitle, peso: .black))
                            .accessibilityAddTraits(.isHeader)
                        if let lugar = [restaurante.cocina, restaurante.direccion, restaurante.ciudad].compactMap({ $0 }).joined(separator: " · ").nilSiVacio {
                            Text(lugar)
                                .font(.rico(.subheadline, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                        }
                    }

                    cifras(resumen)

                    if !resumen.platos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            TituloSeccion(Text("Lo que pediste", bundle: .module))
                            VStack(spacing: 0) {
                                ForEach(Array(resumen.platos.enumerated()), id: \.element.nombre) { posicion, plato in
                                    filaPlato(plato)
                                    if posicion < resumen.platos.count - 1 { Divider() }
                                }
                            }
                            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.ricoLinea))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TituloSeccion(Text("Tus visitas", bundle: .module))
                        ForEach(resumen.visitas) { visita in
                            Button {
                                visitaEditada = visita
                            } label: {
                                filaVisita(visita)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Medidas.margen)
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.ricoFondo)
        .safeAreaInset(edge: .bottom) {
            Button {
                nuevaVisita = true
            } label: {
                Text("Nueva visita", bundle: .module)
            }
            .buttonStyle(.ricoPrincipal)
            .padding(.horizontal, Medidas.margen)
            .padding(.vertical, 12)
            .fondoBarraInferior()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guardandoEnLista = true
                } label: {
                    Image(systemName: (restaurante.listas ?? []).isEmpty ? "bookmark" : "bookmark.fill")
                }
                .accessibilityLabel(Text("Guardar en una lista", bundle: .module))
            }
        }
        .sheet(isPresented: $guardandoEnLista) {
            SelectorListasView(restaurante: restaurante)
        }
        .sheet(item: $visitaEditada) { visita in
            NavigationStack {
                FichaRapidaView(modelo: FichaRapidaModelo(visita: visita))
            }
        }
        .sheet(isPresented: $nuevaVisita) {
            NavigationStack {
                FichaRapidaView(modelo: FichaRapidaModelo(restaurante: restaurante))
            }
        }
    }

    // MARK: Vistas

    private func cifras(_ resumen: ResumenRestaurante) -> some View {
        HStack(spacing: 8) {
            cifra(
                valor: Text(verbatim: "\(resumen.visitas.count)"),
                etiqueta: resumen.visitas.count == 1 ? Text("visita", bundle: .module) : Text("visitas", bundle: .module)
            )
            cifra(valor: Text(verbatim: resumen.notaMedia.map(NotaTexto.texto) ?? "–"), etiqueta: Text("nota media", bundle: .module))
            cifra(valor: Text(verbatim: resumen.gastoMedioPorPersona?.textoMoneda ?? "–"), etiqueta: Text("por persona", bundle: .module))
        }
    }

    private func cifra(valor: Text, etiqueta: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            valor
                .font(.rico(.title2, peso: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            etiqueta
                .font(.rico(.caption, peso: .bold))
                .foregroundStyle(Color.ricoSecundario)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.ricoLinea))
        .accessibilityElement(children: .combine)
    }

    private func filaPlato(_ plato: PlatoResumido) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(plato.nombre)
                    .font(.rico(.body, peso: .heavy))
                Text("^[\(plato.veces) vez](inflect: true)", bundle: .module)
                    .font(.rico(.caption, peso: .bold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            Spacer()
            if let valoracion = plato.ultimaValoracion {
                EtiquetaValoracion(valoracion: valoracion)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func filaVisita(_ visita: Visita) -> some View {
        HStack {
            Text(FormatoFecha.corta(visita.fecha))
                .font(.rico(.subheadline, peso: .bold))
            Spacer()
            if let estrellas = visita.estrellas {
                EstrellasView(nota: estrellas, tamano: 12)
            }
            if let porPersona = visita.importePorPersona {
                Text(porPersona.textoMoneda)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.ricoSecundario)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Medidas.toqueMinimo)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Editar la visita", bundle: .module))
    }
}

struct EtiquetaValoracion: View {
    let valoracion: ValoracionPlato

    var body: some View {
        texto
            .font(.rico(.caption, peso: .heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(primerPlano)
            .background(fondo, in: Capsule())
    }

    private var texto: Text {
        switch valoracion {
        case .encanto: Text("Me encantó", bundle: .module)
        case .bien: Text("Bien", bundle: .module)
        case .noRepetiria: Text("No repetiría", bundle: .module)
        }
    }

    private var primerPlano: Color {
        switch valoracion {
        case .encanto: .ricoVerde
        case .bien: .ricoTinta
        case .noRepetiria: .ricoTomateTexto
        }
    }

    private var fondo: Color {
        switch valoracion {
        case .encanto: .ricoVerdeSuave
        case .bien: .ricoSuperficieHundida
        case .noRepetiria: .ricoTomateSuave
        }
    }
}
