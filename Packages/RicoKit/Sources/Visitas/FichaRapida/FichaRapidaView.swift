import SwiftUI
import SwiftData
import PhotosUI
import DesignSystem
import Modelos
import RicoCore

/// Ficha rápida de valoración: se completa con una mano en menos de 20 segundos.
public struct FichaRapidaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var modelo: FichaRapidaModelo
    @State private var seleccionFotos: [PhotosPickerItem] = []
    @State private var sugeridas: [FotoCarrete] = []
    @State private var mostrarErrorGuardar = false
    @FocusState private var campoActivo: Campo?

    private let sugeridor: any SugeridorFotos
    private let alGuardar: (Visita) -> Void

    enum Campo: Hashable {
        case importe
        case plato(UUID)
        case notas
    }

    public init(
        modelo: FichaRapidaModelo,
        sugeridor: any SugeridorFotos = SugeridorFotosCarrete(),
        alGuardar: @escaping (Visita) -> Void = { _ in }
    ) {
        _modelo = State(initialValue: modelo)
        self.sugeridor = sugeridor
        self.alGuardar = alGuardar
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecera
                notaEstrellas
                tarjetaImporte
                volverias
                seccionPlatos
                seccionFotos
                seccionNotas
            }
            .padding(.horizontal, Medidas.margen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ricoFondo)
        .safeAreaInset(edge: .bottom) { barraGuardar }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { cerrar() } label: { Text("Cancelar", bundle: .module) }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button { campoActivo = nil } label: { Text("Listo", bundle: .module) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargarSugeridas() }
        .onChange(of: seleccionFotos) { _, nuevas in
            Task { await anadirDelSelector(nuevas) }
        }
        .alert(Text("No se pudo guardar la visita", bundle: .module), isPresented: $mostrarErrorGuardar) {
            Button { } label: { Text("Vale", bundle: .module) }
        }
    }

    // MARK: Secciones

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(modelo.nombreRestaurante)
                .font(.rico(.largeTitle, peso: .black))
                .foregroundStyle(Color.ricoTinta)
                .accessibilityAddTraits(.isHeader)
            if let lugar = modelo.lugarTexto {
                Text(lugar)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
            if modelo.esManual {
                DatePicker(selection: $modelo.fecha, in: ...Date.now) {
                    Text("Fecha", bundle: .module)
                }
                .font(.rico(.subheadline, peso: .semibold))
                .tint(.ricoTomate)
                .padding(.top, 6)
            }
        }
    }

    private var notaEstrellas: some View {
        VStack(spacing: 4) {
            SelectorEstrellas(nota: $modelo.estrellas)
            Group {
                if modelo.estrellas > 0 {
                    Text("\(NotaTexto.texto(modelo.estrellas)) de 5", bundle: .module)
                } else {
                    Text("Toca para valorar", bundle: .module)
                }
            }
            .font(.rico(.subheadline, peso: .bold))
            .foregroundStyle(Color.ricoSecundario)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var tarjetaImporte: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importe", bundle: .module)
                        .font(.rico(.footnote, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField(text: $modelo.importeTexto, prompt: Text("0,00", bundle: .module)) {
                            Text("Importe", bundle: .module)
                        }
                        .keyboardType(.decimalPad)
                        .focused($campoActivo, equals: .importe)
                        .font(.rico(.title, peso: .black))
                        .fixedSize()
                        Text(verbatim: "€")
                            .font(.rico(.title, peso: .black))
                            .accessibilityHidden(true)
                    }
                }

                Stepper(value: $modelo.comensales, in: 1...30) {
                    Text("^[\(modelo.comensales) comensal](inflect: true)", bundle: .module)
                        .font(.rico(.body, peso: .bold))
                }

                Picker(selection: $modelo.pagueTodo) {
                    Text("Pagué todo", bundle: .module).tag(true)
                    Text("Pagué mi parte", bundle: .module).tag(false)
                } label: {
                    Text("Quién pagó", bundle: .module)
                }
                .pickerStyle(.segmented)

                if let porPersona = modelo.textoPorPersona {
                    Text("\(porPersona) por persona", bundle: .module)
                        .font(.rico(.subheadline, peso: .bold))
                        .foregroundStyle(Color.ricoSecundario)
                }
            }
        }
    }

    private var volverias: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Volverías?", bundle: .module)
                .font(.rico(.headline, peso: .heavy))
            Pastillas(
                opciones: [
                    (Volveria.si, Text("Sí", bundle: .module)),
                    (Volveria.quiza, Text("Quizá", bundle: .module)),
                    (Volveria.no, Text("No", bundle: .module))
                ],
                seleccion: $modelo.volveria
            )
        }
    }

    private var seccionPlatos: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Platos", bundle: .module)
                    .font(.rico(.headline, peso: .heavy))
                Spacer()
                Button {
                    modelo.anadirPlato()
                    campoActivo = modelo.platos.last.map { .plato($0.id) }
                } label: {
                    Label { Text("Añadir plato", bundle: .module) } icon: { Image(systemName: "plus") }
                        .font(.rico(.subheadline, peso: .heavy))
                }
                .frame(minHeight: Medidas.toqueMinimo)
            }

            ForEach($modelo.platos) { $plato in
                Tarjeta {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField(text: $plato.nombre, prompt: Text("Nombre del plato", bundle: .module)) {
                                Text("Plato", bundle: .module)
                            }
                            .font(.rico(.body, peso: .bold))
                            .focused($campoActivo, equals: .plato(plato.id))
                            .submitLabel(.done)
                            Button {
                                modelo.quitarPlato(plato.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.ricoSecundario)
                                    .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Quitar plato", bundle: .module))
                        }
                        Pastillas(
                            opciones: [
                                (ValoracionPlato.encanto, Text("Me encantó", bundle: .module)),
                                (ValoracionPlato.bien, Text("Bien", bundle: .module)),
                                (ValoracionPlato.noRepetiria, Text("No repetiría", bundle: .module))
                            ],
                            seleccion: $plato.valoracion,
                            altura: 36
                        )
                    }
                }
            }
        }
    }

    private var seccionFotos: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fotos", bundle: .module)
                    .font(.rico(.headline, peso: .heavy))
                Spacer()
                Text("\(modelo.fotos.count) de \(LimitesGratis.fotosPorVisita)", bundle: .module)
                    .font(.rico(.footnote, peso: .bold))
                    .foregroundStyle(Color.ricoSecundario)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(modelo.fotos) { foto in
                    miniatura(foto.miniatura)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                modelo.quitarFoto(foto.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .font(.title3)
                                    .frame(minWidth: Medidas.toqueMinimo, minHeight: Medidas.toqueMinimo)
                            }
                            .accessibilityLabel(Text("Quitar foto", bundle: .module))
                        }
                }
                if modelo.fotosRestantes > 0 {
                    PhotosPicker(selection: $seleccionFotos, maxSelectionCount: modelo.fotosRestantes, matching: .images, photoLibrary: .shared()) {
                        RoundedRectangle(cornerRadius: Medidas.radioControl)
                            .strokeBorder(Color.ricoLinea, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .frame(height: 100)
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.title2)
                                    .foregroundStyle(Color.ricoSecundario)
                            }
                    }
                    .accessibilityLabel(Text("Añadir foto", bundle: .module))
                }
            }

            sugerencias

            if modelo.fotosRestantes == 0 {
                Text("Con Rico Premium, fotos sin límite en cada visita.", bundle: .module)
                    .font(.rico(.footnote, peso: .semibold))
                    .foregroundStyle(Color.ricoSecundario)
            }
        }
    }

    @ViewBuilder
    private var sugerencias: some View {
        let pendientes = sugeridas.filter { !modelo.contiene(fotoDelCarrete: $0.id) }
        if !pendientes.isEmpty, modelo.fotosRestantes > 0 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fotos que hiciste aquí", bundle: .module)
                    .font(.rico(.footnote, peso: .bold))
                    .foregroundStyle(Color.ricoSecundario)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendientes) { foto in
                            Button {
                                Task { await anadirSugerida(foto) }
                            } label: {
                                miniatura(foto.miniatura)
                                    .frame(width: 84, height: 84)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "plus.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(Color.ricoSobreTomate, Color.ricoTomate)
                                            .font(.title3)
                                            .padding(4)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Añadir foto de las \(foto.fecha.formatted(date: .omitted, time: .shortened))", bundle: .module))
                        }
                    }
                }
            }
        } else if sugeridor.permisoSinPedir, modelo.fotosRestantes > 0 {
            Button {
                Task {
                    if await sugeridor.pedirPermiso() { await cargarSugeridas() }
                }
            } label: {
                Label { Text("Ver las fotos que hiciste aquí", bundle: .module) } icon: { Image(systemName: "photo.on.rectangle") }
                    .font(.rico(.subheadline, peso: .heavy))
            }
            .frame(minHeight: Medidas.toqueMinimo)
        }
    }

    private var seccionNotas: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas", bundle: .module)
                .font(.rico(.headline, peso: .heavy))
            TextField(text: $modelo.notas, prompt: Text("¿Qué destacarías?", bundle: .module), axis: .vertical) {
                Text("Notas", bundle: .module)
            }
            .lineLimit(3...8)
            .focused($campoActivo, equals: .notas)
            .padding(12)
            .background(Color.ricoSuperficie, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.ricoLinea))
        }
    }

    private var barraGuardar: some View {
        Button(action: guardar) {
            Text("Guardar visita", bundle: .module)
        }
        .buttonStyle(.ricoPrincipal)
        .disabled(!modelo.puedeGuardar)
        .padding(.horizontal, Medidas.margen)
        .padding(.vertical, 12)
        .fondoBarraInferior()
    }

    private func miniatura(_ datos: Data) -> some View {
        Color.ricoSuperficieHundida
            .frame(height: 100)
            .overlay {
                ImagenVisita(miniatura: datos, semilla: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: Medidas.radioControl))
            .accessibilityHidden(true)
    }

    // MARK: Acciones

    private func guardar() {
        do {
            let visita = try modelo.guardar(en: contexto)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            alGuardar(visita)
            cerrar()
        } catch {
            mostrarErrorGuardar = true
        }
    }

    private func cargarSugeridas() async {
        guard sugeridor.permisoConcedido else { return }
        let desde = modelo.fecha.addingTimeInterval(-3 * 3600)
        let hasta = modelo.fecha.addingTimeInterval(3 * 3600)
        sugeridas = await sugeridor.fotos(desde: desde, hasta: hasta, latitud: modelo.latitud, longitud: modelo.longitud)
    }

    private func anadirSugerida(_ foto: FotoCarrete) async {
        guard let datos = await sugeridor.datosCompletos(id: foto.id),
              let procesada = await ProcesadorFotos.procesarEnSegundoPlano(datos) else { return }
        modelo.anadirFoto(BorradorFoto(
            miniatura: procesada.miniatura,
            datos: procesada.datos,
            fecha: foto.fecha,
            identificadorCarrete: foto.id
        ))
    }

    private func anadirDelSelector(_ elementos: [PhotosPickerItem]) async {
        guard !elementos.isEmpty else { return }
        for elemento in elementos {
            guard let datos = try? await elemento.loadTransferable(type: Data.self),
                  let procesada = await ProcesadorFotos.procesarEnSegundoPlano(datos) else { continue }
            modelo.anadirFoto(BorradorFoto(
                miniatura: procesada.miniatura,
                datos: procesada.datos,
                fecha: elemento.itemIdentifier.flatMap(SugeridorFotosCarrete.fechaDeCreacion) ?? .now,
                identificadorCarrete: elemento.itemIdentifier
            ))
        }
        seleccionFotos = []
    }
}
