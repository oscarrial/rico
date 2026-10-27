import Foundation
import Testing
@testable import RicoCore

@Suite("Filtro de sitios del mapa")
struct FiltroSitiosTests {
    typealias Cat = FiltroSitios.Categoria

    @Test func comerSoloAceptaRestaurantes() {
        let comer = FiltroSitios.categorias(de: [.comer])
        #expect(FiltroSitios.esValido(nombre: "Taberna O Grelo", categoria: Cat.restaurante, permitidas: comer))
        #expect(!FiltroSitios.esValido(nombre: "Panadería Calo", categoria: Cat.panaderia, permitidas: comer))
        #expect(!FiltroSitios.esValido(nombre: "Bodegas Gallegas", categoria: Cat.bodega, permitidas: comer))
    }

    @Test func lasTiendasDeComidaNuncaEntran() {
        #expect(!FiltroSitios.esValido(nombre: "Froiz", categoria: Cat.tiendaComida, permitidas: FiltroSitios.restauracion))
        #expect(!FiltroSitios.restauracion.contains(Cat.tiendaComida))
    }

    @Test func tiendasMalClasificadasSeQuitanPorElNombre() {
        let todas = FiltroSitios.restauracion
        #expect(!FiltroSitios.esValido(nombre: "Supermercado Gadis", categoria: Cat.restaurante, permitidas: todas))
        #expect(!FiltroSitios.esValido(nombre: "Frutería Lola", categoria: Cat.cafe, permitidas: todas))
        #expect(!FiltroSitios.esValido(nombre: "Carrefour Express", categoria: nil, permitidas: todas))
        #expect(!FiltroSitios.esValido(nombre: "Ultramarinos Ángel", categoria: Cat.restaurante, permitidas: todas))
    }

    @Test func losRestaurantesConNombresTraicionerosSeQuedan() {
        let todas = FiltroSitios.restauracion
        #expect(FiltroSitios.esValido(nombre: "Venta de Pepe", categoria: Cat.restaurante, permitidas: todas))
        #expect(FiltroSitios.esValido(nombre: "Menú del Día Casa Lola", categoria: Cat.restaurante, permitidas: todas))
        #expect(FiltroSitios.esValido(nombre: "Café Moderno", categoria: Cat.cafe, permitidas: todas))
        #expect(FiltroSitios.esValido(nombre: "La Bodeguilla", categoria: Cat.bar, permitidas: todas))
    }

    @Test func variosTiposSumanSusCategorias() {
        let cafeYCopas = FiltroSitios.categorias(de: [.cafe, .copas])
        #expect(cafeYCopas.contains(Cat.cafe))
        #expect(cafeYCopas.contains(Cat.bar))
        #expect(!cafeYCopas.contains(Cat.restaurante))
    }
}

@Suite("Detección de visitas por ubicación")
struct EvaluadorEstanciaTests {
    static let madrid: Calendar = {
        var calendario = Calendar(identifier: .gregorian)
        // Hora de España en octubre (+2). Desfase fijo: en Linux puede no haber base de zonas horarias.
        calendario.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
        return calendario
    }()

    let evaluador = EvaluadorEstancia(calendario: Self.madrid)
    // Sábado 24 de octubre de 2026, hora de comer.
    let llegada = Self.hora(14, 10)
    // Taberna en Vigo y una frutería a 20 m.
    let taberna = CandidatoEstancia(id: "taberna", nombre: "Taberna O Grelo", categoria: FiltroSitios.Categoria.restaurante, latitud: 42.2395, longitud: -8.7205)
    let fruteria = CandidatoEstancia(id: "fruta", nombre: "Frutería Lola", categoria: FiltroSitios.Categoria.restaurante, latitud: 42.23965, longitud: -8.7205)

    static func hora(_ h: Int, _ m: Int = 0, dia: Int = 24) -> Date {
        madrid.date(from: DateComponents(year: 2026, month: 10, day: dia, hour: h, minute: m))!
    }

    func estancia(minutos: Double, precision: Double = 30, desplazamientoLat: Double = 0.0001, desde: Date? = nil) -> Estancia {
        let inicio = desde ?? llegada
        return Estancia(
            latitud: 42.2395 + desplazamientoLat,
            longitud: -8.7205,
            llegada: inicio,
            salida: inicio.addingTimeInterval(minutos * 60),
            precisionMetros: precision
        )
    }

    /// Un bar con nombre de restaurante a `metros` al norte del punto de la estancia por defecto.
    func bar(_ id: String, aMetros metros: Double) -> CandidatoEstancia {
        CandidatoEstancia(id: id, nombre: "Bar \(id)", categoria: FiltroSitios.Categoria.restaurante, latitud: 42.2396 + metros / 111_195, longitud: -8.7205)
    }

    @Test func unaComidaDeUnaHoraPreguntaPorElRestaurante() {
        let decision = evaluador.decidir(estancia(minutos: 65), candidatos: [fruteria, taberna])
        guard case let .preguntar(id, distancia) = decision else {
            Issue.record("Se esperaba preguntar y llegó \(decision)")
            return
        }
        #expect(id == "taberna")
        #expect(distancia < 20)
    }

    @Test func sigueAhiNoSePreguntaTodavia() {
        var enCurso = estancia(minutos: 60)
        enCurso.salida = .distantFuture
        #expect(evaluador.decidir(enCurso, candidatos: [taberna]) == .ignorar(.enCurso))
    }

    @Test func pasarUnRatoNoEsComer() {
        #expect(evaluador.decidir(estancia(minutos: 15), candidatos: [taberna]) == .ignorar(.corta))
    }

    @Test func todaLaTardeEsCasaOTrabajo() {
        #expect(evaluador.decidir(estancia(minutos: 6 * 60), candidatos: [taberna]) == .ignorar(.larga))
    }

    @Test func conPosicionMalaNoSeAdivina() {
        #expect(evaluador.decidir(estancia(minutos: 60, precision: 150), candidatos: [taberna]) == .ignorar(.imprecisa))
    }

    @Test func siYaHayUnPagoAEsaHoraNoSeDuplica() {
        let pago = llegada.addingTimeInterval(50 * 60)
        #expect(evaluador.decidir(estancia(minutos: 60), candidatos: [taberna], registradas: [pago]) == .ignorar(.yaRegistrada))
    }

    @Test func unaVisitaDeOtroMomentoNoCuenta() {
        let ayer = llegada.addingTimeInterval(-24 * 3600)
        if case .preguntar = evaluador.decidir(estancia(minutos: 60), candidatos: [taberna], registradas: [ayer]) {
        } else {
            Issue.record("Una visita del día anterior no debería impedir preguntar")
        }
    }

    @Test func sitiosLejosOSilenciadosNoSeProponen() {
        let lejos = estancia(minutos: 60, desplazamientoLat: 0.003) // unos 330 m
        #expect(evaluador.decidir(lejos, candidatos: [taberna]) == .ignorar(.sinCandidatos))
        #expect(evaluador.decidir(estancia(minutos: 60), candidatos: [taberna], silenciados: ["taberna"]) == .ignorar(.sinCandidatos))
    }

    @Test func aMediaTardeNoEsUnaComida() {
        // Un museo, la siesta o compras de 17:00 a 18:15.
        let tarde = estancia(minutos: 75, desde: Self.hora(17))
        #expect(evaluador.decidir(tarde, candidatos: [taberna]) == .ignorar(.fueraDeHora))
    }

    @Test func unaCenaQuePasaDeMedianocheCuenta() {
        let cena = estancia(minutos: 105, desde: Self.hora(22, 30))
        if case .preguntar = evaluador.decidir(cena, candidatos: [taberna]) {
        } else {
            Issue.record("Una cena de 22:30 a 00:15 debería preguntar")
        }
    }

    @Test func juntoAlHotelNoSePregunta() {
        let hotel = LugarDormido(latitud: 42.2397, longitud: -8.7206, fecha: Self.hora(9))
        #expect(evaluador.decidir(estancia(minutos: 60), candidatos: [taberna], noches: [hotel]) == .ignorar(.dondeDuermes))

        let otraCiudad = LugarDormido(latitud: 42.25, longitud: -8.7205, fecha: Self.hora(9))
        if case .preguntar = evaluador.decidir(estancia(minutos: 60), candidatos: [taberna], noches: [otraCiudad]) {
        } else {
            Issue.record("Un sitio donde se durmió a más de 1 km no debería impedir preguntar")
        }
    }

    @Test func conDosBaresCasiIgualDeCercaNoSeAdivina() {
        let dudosa = evaluador.decidir(estancia(minutos: 60), candidatos: [bar("a", aMetros: 40), bar("b", aMetros: -48)])
        #expect(dudosa == .ignorar(.ambigua))

        // Si uno está muy cerca, es ese aunque haya otro al lado.
        let cerca = bar("a", aMetros: 10)
        let punto = estancia(minutos: 60)
        let clara = evaluador.decidir(punto, candidatos: [cerca, bar("b", aMetros: -15)])
        #expect(clara == .preguntar(candidatoID: "a", distanciaMetros: DistanciaGeo.metros(punto.latitud, punto.longitud, cerca.latitud, cerca.longitud)))
    }

    @Test func lasNochesSeReconocen() {
        func noche(_ desde: Date, _ hasta: Date) -> Estancia {
            Estancia(latitud: 37.176, longitud: -3.598, llegada: desde, salida: hasta, precisionMetros: 40)
        }
        #expect(evaluador.esNoche(noche(Self.hora(23, 30, dia: 23), Self.hora(9, 0))))
        #expect(!evaluador.esNoche(noche(Self.hora(15), Self.hora(19))))
        // iOS no vio la llegada: si sale por la mañana, ha dormido allí.
        #expect(evaluador.esNoche(noche(.distantPast, Self.hora(10))))
        #expect(!evaluador.esNoche(noche(.distantPast, Self.hora(20))))
    }
}
