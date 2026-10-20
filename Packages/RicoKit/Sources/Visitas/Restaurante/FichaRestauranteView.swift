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

    public init(restaurante: Restaurante) {
        self.restaurante = restaurante
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ImagenVisita(miniatura: fotoPortada, semilla: restaurante.id.semilla)
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

                    cifras

                    if !platos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            TituloSeccion(Text("Lo que pediste", bundle: .module))
                            VStack(spacing: 0) {
                                ForEach(platos, id: \.nombre) { plato in
                                    filaPlato(plato)
                                    if plato.nombre != platos.last?.nombre { Divider() }
                                }
                            }
                            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.ricoLinea))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TituloSeccion(Text("Tus visitas", bundle: .module))
                        ForEach(visitas) { visita in
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

    // MARK: Datos

    private var visitas: [Visita] {
        (restaurante.visitas ?? [])
            .filter { $0.estado == .valorada }
            .sorted { $0.fecha > $1.fecha }
    }

    private var fotoPortada: Data? {
        visitas.lazy.compactMap { $0.fotosOrdenadas.first?.miniatura }.first
    }

    private var notaMedia: Double? {
        let notas = visitas.compactMap(\.estrellas)
        guard !notas.isEmpty else { return nil }
        return notas.reduce(0, +) / Double(notas.count)
    }

    private var gastoMedioPorPersona: Importe? {
        let importes = visitas.compactMap(\.importePorPersona)
        guard let primero = importes.first else { return nil }
        let media = importes.map(\.centimos).reduce(0, +) / importes.count
        return Importe(centimos: media, divisa: primero.divisa)
    }

    private struct ResumenPlato {
        let nombre: String
        let veces: Int
        let ultimaValoracion: ValoracionPlato?
    }

    /// Platos agrupados por nombre, los más pedidos primero.
    private var platos: [ResumenPlato] {
        var grupos: [String: (nombre: String, veces: Int, ultima: ValoracionPlato?)] = [:]
        // `visitas` va de la más reciente a la más antigua: la primera valoración que se ve es la última.
        for visita in visitas {
            for plato in visita.platosOrdenados {
                let clave = plato.nombre.lowercased()
                if var grupo = grupos[clave] {
                    grupo.veces += 1
                    if grupo.ultima == nil { grupo.ultima = plato.valoracion }
                    grupos[clave] = grupo
                } else {
                    grupos[clave] = (plato.nombre, 1, plato.valoracion)
                }
            }
        }
        return grupos.values
            .map { ResumenPlato(nombre: $0.nombre, veces: $0.veces, ultimaValoracion: $0.ultima) }
            .sorted { ($0.veces, $1.nombre) > ($1.veces, $0.nombre) }
    }

    // MARK: Vistas

    private var cifras: some View {
        HStack(spacing: 8) {
            cifra(
                valor: Text(verbatim: "\(visitas.count)"),
                etiqueta: visitas.count == 1 ? Text("visita", bundle: .module) : Text("visitas", bundle: .module)
            )
            cifra(valor: Text(verbatim: notaMedia.map(NotaTexto.texto) ?? "–"), etiqueta: Text("nota media", bundle: .module))
            cifra(valor: Text(verbatim: gastoMedioPorPersona?.textoMoneda ?? "–"), etiqueta: Text("por persona", bundle: .module))
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

    private func filaPlato(_ plato: ResumenPlato) -> some View {
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
