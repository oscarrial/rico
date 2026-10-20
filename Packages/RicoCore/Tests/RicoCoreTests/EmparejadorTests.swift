import Testing
@testable import RicoCore

@Suite("Emparejado de comercio")
struct EmparejadorTests {
    let emparejador = Emparejador()

    @Test func nombreClaroYCercaSeAsignaSolo() {
        let decision = emparejador.decidir(
            comercio: "REST CASA PEPE SL",
            candidatos: [
                CandidatoLugar(id: "pepe", nombre: "Casa Pepe", distanciaMetros: 20),
                CandidatoLugar(id: "otro", nombre: "Mesón do Peixe", distanciaMetros: 60)
            ]
        )
        guard case let .asignado(id, puntuacion, porAlias) = decision else {
            Issue.record("Se esperaba asignado y llegó \(decision)")
            return
        }
        #expect(id == "pepe")
        #expect(puntuacion > 0.75)
        #expect(!porAlias)
    }

    @Test func nombreBuenoPeroLejosSePropone() {
        // El caso de la pantalla de diseño: «SUMUP *CAFE ALAMEDA» con tres sitios parecidos.
        let decision = emparejador.decidir(
            comercio: "SUMUP *CAFE ALAMEDA",
            candidatos: [
                CandidatoLugar(id: "bistro", nombre: "Alameda Bistró", distanciaMetros: 140),
                CandidatoLugar(id: "cafe", nombre: "Café Alameda", distanciaMetros: 90),
                CandidatoLugar(id: "tapas", nombre: "La Alameda Tapas", distanciaMetros: 150),
                CandidatoLugar(id: "lejano", nombre: "Pulpería Ezequiel", distanciaMetros: 145)
            ]
        )
        guard case let .proponer(propuestas) = decision else {
            Issue.record("Se esperaba proponer y llegó \(decision)")
            return
        }
        #expect(propuestas.count == 3)
        #expect(propuestas.first?.candidato.id == "cafe")
        #expect(!propuestas.contains { $0.candidato.id == "lejano" })
    }

    @Test func nombreIrreconocibleVaALaBandeja() {
        let decision = emparejador.decidir(
            comercio: "PAGO XQW SERVICIOS",
            candidatos: [CandidatoLugar(id: "grelo", nombre: "Taberna O Grelo", distanciaMetros: 120)]
        )
        guard case let .bandeja(propuestas) = decision else {
            Issue.record("Se esperaba bandeja y llegó \(decision)")
            return
        }
        #expect(propuestas.map(\.candidato.id) == ["grelo"])
    }

    @Test func sinCandidatosVaALaBandejaVacia() {
        #expect(emparejador.decidir(comercio: "O GRELO", candidatos: []) == .bandeja([]))
    }

    @Test func elAliasAprendidoGanaSiempre() {
        let decision = emparejador.decidir(
            comercio: "REST CASA PEPE SL",
            candidatos: [],
            alias: ["casa pepe": "restaurante-42"]
        )
        #expect(decision == .asignado(id: "restaurante-42", puntuacion: 1, porAlias: true))
    }

    @Test(arguments: ["MERCADONA VIGO 2231", "REPSOL ES 1234", "FARMACIA LDO. GARCIA", "ESTACION DE SERVICIO A9"])
    func noRestauracionSeDescarta(comercio: String) {
        #expect(emparejador.decidir(comercio: comercio, candidatos: []) == .noRestauracion)
    }

    @Test func aIgualdadGanaElYaVisitado() {
        let puntuados = emparejador.puntuar(
            comercioLimpio: "alameda",
            candidatos: [
                CandidatoLugar(id: "nuevo", nombre: "Alameda", distanciaMetros: 50),
                CandidatoLugar(id: "conocido", nombre: "Alameda", distanciaMetros: 50, visitadoAntes: true)
            ]
        )
        #expect(puntuados.first?.candidato.id == "conocido")
    }

    @Test func subconjuntoDePalabrasCuentaComoCasiIgual() {
        #expect(Emparejador.similitudTexto("grelo", "taberna grelo") >= 0.92)
    }
}
