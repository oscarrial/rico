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
    let evaluador = EvaluadorEstancia()
    let llegada = Date(timeIntervalSince1970: 1_790_000_000)
    // Taberna en Vigo y una frutería a 20 m.
    let taberna = CandidatoEstancia(id: "taberna", nombre: "Taberna O Grelo", categoria: FiltroSitios.Categoria.restaurante, latitud: 42.2395, longitud: -8.7205)
    let fruteria = CandidatoEstancia(id: "fruta", nombre: "Frutería Lola", categoria: FiltroSitios.Categoria.restaurante, latitud: 42.23965, longitud: -8.7205)

    func estancia(minutos: Double, precision: Double = 30, desplazamientoLat: Double = 0.0001) -> Estancia {
        Estancia(
            latitud: 42.2395 + desplazamientoLat,
            longitud: -8.7205,
            llegada: llegada,
            salida: llegada.addingTimeInterval(minutos * 60),
            precisionMetros: precision
        )
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
        #expect(evaluador.decidir(estancia(minutos: 60, precision: 500), candidatos: [taberna]) == .ignorar(.imprecisa))
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
}
