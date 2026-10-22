import SwiftUI
import SwiftData
import MapKit
import UIKit
import os
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Pestaña Mapa: tus sitios con pines por nota y «Explorar zona» para encontrar dónde comer cerca.
public struct MapaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.openURL) private var abrirURL

    @Query private var restaurantes: [Restaurante]
    @Query(filter: #Predicate<Lista> { $0.tipoRaw == "quieroProbar" })
    private var listasQuieroProbar: [Lista]

    @State private var modo: ModoMapa = .misSitios
    @State private var posicion: MapCameraPosition = .automatic
    @State private var zonaVisible: ZonaMapa?
    @State private var encuadrado = false
    @State private var seleccion: SeleccionMapa?
    @State private var hoja: HojaVisita?
    @State private var explorador = ExploradorZona()
    @State private var permiso = PermisoUbicacion()
    @State private var centrarAlPermitir = false
    @State private var avisoSinPermiso = false
    @State private var errorGuardar = false
    @State private var anadidos = 0

    public init() {}

    public var body: some View {
        let pines = SitiosMapa.pines(restaurantes, quieroProbar: SitiosMapa.idsQuieroProbar(listasQuieroProbar))
        let explorados = modo == .explorar ? SitiosMapa.sinRepetir(explorador.lugares, pines: pines) : []
        return NavigationStack {
            mapa(pines: pines, explorados: explorados)
                .safeAreaInset(edge: .top, spacing: 0) {
                    controlesSuperiores(explorados: explorados)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    zonaInferior(pines: pines)
                }
                .navigationTitle(Text("Mapa", bundle: .module))
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Restaurante.self) { restaurante in
                    FichaRestauranteView(restaurante: restaurante)
                }
                .sheet(item: $hoja) { hoja in
                    NavigationStack {
                        FichaRapidaView(modelo: hoja.modelo()) { visita in
                            if let restaurante = visita.restaurante {
                                seleccion = .mio(restaurante)
                            }
                        }
                    }
                }
                .onAppear { encuadrarSiHaceFalta(pines) }
                .onChange(of: pines.count) { encuadrarSiHaceFalta(pines) }
                .onChange(of: permiso.estado) { alCambiarPermiso(pines) }
                .task(id: modo) {
                    if modo == .explorar {
                        await explorarZonaVisible()
                    } else {
                        explorador.limpiar()
                    }
                }
                .sensoryFeedback(.success, trigger: anadidos)
                .alert(Text("Activa la ubicación", bundle: .module), isPresented: $avisoSinPermiso) {
                    Button {
                        if let ajustes = URL(string: UIApplication.openSettingsURLString) { abrirURL(ajustes) }
                    } label: {
                        Text("Abrir Ajustes", bundle: .module)
                    }
                    Button(role: .cancel) {} label: { Text("Ahora no", bundle: .module) }
                } message: {
                    Text("Para centrar el mapa en ti, permite la ubicación a Rico en Ajustes. Mientras, te enseñamos tus sitios.", bundle: .module)
                }
                .alert(Text("No se ha podido guardar", bundle: .module), isPresented: $errorGuardar) {
                    Button(role: .cancel) {} label: { Text("Vale", bundle: .module) }
                } message: {
                    Text("Prueba otra vez en un momento.", bundle: .module)
                }
        }
    }

    // MARK: Mapa

    private func mapa(pines: [PinRestaurante], explorados: [LugarEncontrado]) -> some View {
        Map(position: $posicion) {
            UserAnnotation()

            ForEach(explorados) { lugar in
                Annotation(lugar.nombre, coordinate: CLLocationCoordinate2D(latitude: lugar.latitud, longitude: lugar.longitud)) {
                    Button {
                        seleccionar(.explorado(lugar))
                    } label: {
                        PinMapaView(categoria: .explorar, nota: nil, seleccionado: seleccion == .explorado(lugar))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(lugar.nombre), sin visitar", bundle: .module))
                    .accessibilityHint(Text("Muestra el sitio", bundle: .module))
                }
                .annotationTitles(.hidden)
            }

            ForEach(pines) { pin in
                Annotation(pin.restaurante.nombre, coordinate: CLLocationCoordinate2D(latitude: pin.latitud, longitude: pin.longitud)) {
                    Button {
                        seleccionar(.mio(pin.restaurante))
                    } label: {
                        PinMapaView(categoria: pin.categoria, nota: pin.nota, seleccionado: seleccion == .mio(pin.restaurante))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(etiquetaAccesible(pin))
                    .accessibilityHint(Text("Muestra el sitio", bundle: .module))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket])))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { camara in
            zonaVisible = ZonaMapa(region: camara.region)
        }
    }

    private func etiquetaAccesible(_ pin: PinRestaurante) -> Text {
        if let nota = pin.nota {
            return Text("\(pin.restaurante.nombre), \(NotaTexto.texto(nota)) de 5 estrellas", bundle: .module)
        }
        return Text("\(pin.restaurante.nombre), en Quiero probar", bundle: .module)
    }

    // MARK: Controles de arriba

    private func controlesSuperiores(explorados: [LugarEncontrado]) -> some View {
        VStack(spacing: 10) {
            ContenedorCristal {
                HStack(spacing: 10) {
                    selectorModo
                    botonUbicacion
                }
            }
            if modo == .explorar {
                selectorTipos
                    .transition(.opacity)
                avisoExplorar(explorados: explorados)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Medidas.margen)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var selectorModo: some View {
        HStack(spacing: 4) {
            ForEach(ModoMapa.allCases, id: \.self) { opcion in
                let activo = modo == opcion
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        modo = opcion
                        seleccion = nil
                    }
                } label: {
                    opcion.titulo
                        .font(.rico(.subheadline, peso: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(activo ? Color.ricoTinta : Color.ricoSecundario)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: Medidas.toqueMinimo)
                        .background {
                            if activo {
                                Capsule().fill(Color.ricoSuperficie)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activo ? .isSelected : [])
            }
        }
        .padding(4)
        .fondoFlotante(Capsule())
        .sensoryFeedback(.selection, trigger: modo)
    }

    /// Comer, café o copas. Se pueden marcar varios; siempre queda al menos uno.
    private var selectorTipos: some View {
        HStack(spacing: 8) {
            ForEach(TipoSitio.allCases, id: \.self) { tipo in
                let activo = explorador.tipos.contains(tipo)
                Button {
                    alternar(tipo)
                } label: {
                    Label { tipo.titulo } icon: { Image(systemName: tipo.simbolo) }
                        .font(.rico(.subheadline, peso: .heavy))
                        .lineLimit(1)
                        .foregroundStyle(activo ? Color.ricoSobreTomate : Color.ricoTinta)
                        .padding(.horizontal, 14)
                        .frame(minHeight: Medidas.toqueMinimo)
                        .background {
                            if activo {
                                Capsule().fill(Color.ricoTomate)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .fondoFlotante(Capsule())
                .accessibilityAddTraits(activo ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: explorador.tipos)
    }

    private func alternar(_ tipo: TipoSitio) {
        var tipos = explorador.tipos
        if tipos.contains(tipo) {
            guard tipos.count > 1 else { return }
            tipos.remove(tipo)
        } else {
            tipos.insert(tipo)
        }
        explorador.tipos = tipos
        seleccion = nil
        Task {
            if let zona = explorador.zonaBuscada ?? zonaVisible {
                await explorador.explorar(zona)
            }
        }
    }

    private var botonUbicacion: some View {
        Button(action: centrarEnMiPosicion) {
            Image(systemName: permiso.permitida ? "location.fill" : "location")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ricoTinta)
                .frame(width: Medidas.toqueMinimo + 8, height: Medidas.toqueMinimo + 8)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .fondoFlotante(Circle())
        .accessibilityLabel(Text("Centrar en tu posición", bundle: .module))
    }

    @ViewBuilder
    private func avisoExplorar(explorados: [LugarEncontrado]) -> some View {
        switch explorador.estado {
        case .buscando:
            HStack(spacing: 8) {
                ProgressView()
                Text("Buscando sitios para comer…", bundle: .module)
            }
            .modifier(EstiloAviso())
        case .error:
            botonBuscarAqui(Text("No se ha podido buscar. Reintentar", bundle: .module))
        case .inactivo, .listo:
            if let zonaVisible, zonaVisible != explorador.zonaBuscada {
                botonBuscarAqui(Text("Buscar en esta zona", bundle: .module))
            } else if explorador.estado == .listo, explorados.isEmpty {
                Text("No hay sitios nuevos para comer en esta zona.", bundle: .module)
                    .modifier(EstiloAviso())
            }
        }
    }

    private func botonBuscarAqui(_ titulo: Text) -> some View {
        Button {
            Task { await explorarZonaVisible() }
        } label: {
            Label { titulo } icon: { Image(systemName: "magnifyingglass") }
                .modifier(EstiloAviso())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Abajo: tarjeta o estado vacío

    @ViewBuilder
    private func zonaInferior(pines: [PinRestaurante]) -> some View {
        Group {
            switch seleccion {
            case let .mio(restaurante):
                TarjetaSitioMapa(
                    restaurante: restaurante,
                    alGuardarVisita: { hoja = .restaurante(restaurante) },
                    alCerrar: { seleccionar(nil) }
                )
                .id(restaurante.id)
            case let .explorado(lugar):
                TarjetaExploradoMapa(
                    lugar: lugar,
                    alGuardarVisita: { hoja = .lugar(lugar) },
                    alQuererProbar: { anadirAQuieroProbar(lugar) },
                    alCerrar: { seleccionar(nil) }
                )
                .id(lugar.id)
            case nil:
                if pines.isEmpty, modo == .misSitios {
                    estadoVacio
                }
            }
        }
        .padding(.horizontal, Medidas.margen)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var estadoVacio: some View {
        Tarjeta {
            HStack(spacing: 14) {
                SimboloRico()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("Aún no hay sitios en tu mapa. Guarda una visita y aparecerá aquí.", bundle: .module)
                    .font(.rico(.subheadline, peso: .semibold))
                    .foregroundStyle(Color.ricoTinta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Acciones

    private func seleccionar(_ nueva: SeleccionMapa?) {
        withAnimation(.snappy(duration: 0.25)) {
            seleccion = nueva
        }
    }

    /// Encuadra todos tus pines la primera vez que los hay.
    private func encuadrarSiHaceFalta(_ pines: [PinRestaurante]) {
        guard !encuadrado, !pines.isEmpty else { return }
        encuadrar(pines)
    }

    private func encuadrar(_ pines: [PinRestaurante]) {
        guard let zona = ZonaMapa.encuadrando(pines.map { (latitud: $0.latitud, longitud: $0.longitud) }) else { return }
        encuadrado = true
        withAnimation(.snappy(duration: 0.3)) {
            posicion = .region(zona.region)
        }
    }

    private func centrarEnMiPosicion() {
        if permiso.permitida {
            withAnimation(.snappy(duration: 0.3)) {
                posicion = .userLocation(fallback: posicion)
            }
        } else if permiso.sinDecidir {
            centrarAlPermitir = true
            permiso.pedir()
        } else {
            // Sin permiso: el mapa vuelve a tus sitios y se explica cómo activarlo.
            let pines = SitiosMapa.pines(restaurantes, quieroProbar: SitiosMapa.idsQuieroProbar(listasQuieroProbar))
            encuadrar(pines)
            avisoSinPermiso = true
        }
    }

    private func alCambiarPermiso(_ pines: [PinRestaurante]) {
        guard centrarAlPermitir, !permiso.sinDecidir else { return }
        centrarAlPermitir = false
        if permiso.permitida {
            withAnimation(.snappy(duration: 0.3)) {
                posicion = .userLocation(fallback: posicion)
            }
        } else {
            encuadrar(pines)
        }
    }

    private func explorarZonaVisible() async {
        guard let zona = zonaVisible else { return }
        await explorador.explorar(zona)
    }

    private func anadirAQuieroProbar(_ lugar: LugarEncontrado) {
        do {
            let resultado = try contexto.anadirAQuieroProbar(lugar)
            anadidos += 1
            seleccionar(.mio(resultado.restaurante))
        } catch {
            Registro.datos.error("No se pudo añadir a Quiero probar: \(String(describing: error), privacy: .private)")
            errorGuardar = true
        }
    }
}

// MARK: Tipos de la pantalla

enum ModoMapa: CaseIterable, Hashable {
    case misSitios
    case explorar

    var titulo: Text {
        switch self {
        case .misSitios: Text("Mis sitios", bundle: .module)
        case .explorar: Text("Explorar zona", bundle: .module)
        }
    }
}

enum SeleccionMapa: Hashable {
    case mio(Restaurante)
    case explorado(LugarEncontrado)
}

/// Qué abre la ficha rápida desde el mapa.
enum HojaVisita: Identifiable {
    case lugar(LugarEncontrado)
    case restaurante(Restaurante)

    var id: String {
        switch self {
        case let .lugar(lugar): "lugar-\(lugar.id)"
        case let .restaurante(restaurante): "restaurante-\(restaurante.id.uuidString)"
        }
    }

    @MainActor
    func modelo() -> FichaRapidaModelo {
        switch self {
        case let .lugar(lugar): FichaRapidaModelo(lugar: lugar)
        case let .restaurante(restaurante): FichaRapidaModelo(restaurante: restaurante)
        }
    }
}

/// Aviso pequeño bajo el selector (buscando, sin resultados, «Buscar en esta zona»).
private struct EstiloAviso: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.rico(.footnote, peso: .heavy))
            .foregroundStyle(Color.ricoTinta)
            .padding(.horizontal, 16)
            .frame(minHeight: Medidas.toqueMinimo)
            .fondoFlotante(Capsule())
    }
}

extension ZonaMapa {
    init(region: MKCoordinateRegion) {
        self.init(
            latitud: region.center.latitude,
            longitud: region.center.longitude,
            latitudDelta: region.span.latitudeDelta,
            longitudDelta: region.span.longitudeDelta
        )
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitud, longitude: longitud),
            span: MKCoordinateSpan(latitudeDelta: latitudDelta, longitudeDelta: longitudDelta)
        )
    }
}

private extension TipoSitio {
    var titulo: Text {
        switch self {
        case .comer: Text("Comer", bundle: .module)
        case .cafe: Text("Café", bundle: .module)
        case .copas: Text("Copas", bundle: .module)
        }
    }

    var simbolo: String {
        switch self {
        case .comer: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .copas: "wineglass.fill"
        }
    }
}
