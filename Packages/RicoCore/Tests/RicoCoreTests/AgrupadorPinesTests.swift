import Testing
@testable import RicoCore

@Suite("Agrupador de pines")
struct AgrupadorPinesTests {
    /// Seis sitios en Vigo y uno en Santiago, vistos con Galicia entera en pantalla.
    let puntos: [(latitud: Double, longitud: Double)] = [
        (42.2370, -8.7230), (42.2380, -8.7210), (42.2360, -8.7190),
        (42.2400, -8.7250), (42.2350, -8.7220), (42.2390, -8.7200),
        (42.8800, -8.5450)
    ]

    @Test func lejosSeJuntanLosQueSePisan() {
        let grupos = AgrupadorPines.grupos(puntos, latitudDelta: 1.2, longitudDelta: 0.8)

        #expect(grupos.count == 2)
        #expect(grupos[0] == [0, 1, 2, 3, 4, 5])
        #expect(grupos[1] == [6])
    }

    @Test func alAcercarseCadaUnoVaSolo() {
        let grupos = AgrupadorPines.grupos(puntos, latitudDelta: 0.002, longitudDelta: 0.002)

        #expect(grupos.count == puntos.count)
    }

    @Test func sinZonaNoSeAgrupa() {
        #expect(AgrupadorPines.grupos(puntos, latitudDelta: 0, longitudDelta: 0).count == puntos.count)
        #expect(AgrupadorPines.grupos([], latitudDelta: 1, longitudDelta: 1).isEmpty)
    }
}
