import Testing
@testable import RicoCore

@Suite("Limpieza de nombres de datáfono")
struct LimpiadorComercioTests {
    // Casos de ejemplo escritos a mano. El conjunto de 200 nombres reales anonimizados
    // del plan se añadirá a `CasosDatafono.swift` con los datos de la beta.
    @Test(arguments: [
        ("REST CASA PEPE SL", "casa pepe"),
        ("RESTAURANTE LA CEPA, S.L.", "la cepa"),
        ("SUMUP *CAFE ALAMEDA", "alameda"),
        ("SQ *BAR O GRELO", "grelo"),
        ("ZTL*TABERNA DA PIEDRA 0023", "taberna da piedra"),
        ("Bar Ñandú 12345", "nandu"),
        ("PIZZERIA DO PORTO S.L.U.", "pizzeria do porto"),
        ("BAR", "bar"),
        ("CAFETERÍA MOLINO TPV2", "molino"),
        ("STRIPE* RAMEN KUROGANE", "ramen kurogane")
    ])
    func limpia(entrada: String, esperado: String) {
        #expect(LimpiadorComercio.limpiar(entrada) == esperado)
    }

    @Test func mismaReglaParaElCandidato() {
        #expect(LimpiadorComercio.limpiar("Café Alameda") == LimpiadorComercio.limpiar("SUMUP *CAFE ALAMEDA"))
    }
}

@Suite("Jaro-Winkler")
struct JaroWinklerTests {
    @Test(arguments: [
        ("martha", "marhta", 0.961),
        ("dwayne", "duane", 0.840),
        ("dixon", "dicksonx", 0.813)
    ])
    func valoresConocidos(a: String, b: String, esperado: Double) {
        #expect(abs(JaroWinkler.similitud(a, b) - esperado) < 0.001)
    }

    @Test func extremos() {
        #expect(JaroWinkler.similitud("casa pepe", "casa pepe") == 1)
        #expect(JaroWinkler.similitud("abc", "") == 0)
        #expect(JaroWinkler.similitud("abc", "xyz") == 0)
    }
}
