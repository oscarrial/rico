import Foundation
import SwiftData
import Testing
import Modelos
import RicoCore
import Visitas

@MainActor
@Suite("Almacén por usuario")
struct AlmacenPorUsuarioTests {
    let grelo = LugarEncontrado(mapItemID: "I-GRELO", nombre: "Taberna O Grelo", ciudad: "Vigo", latitud: 42.2406, longitud: -8.7207)

    /// Carpeta temporal única; se borra al terminar la prueba.
    private func conCarpeta(_ cuerpo: (URL) throws -> Void) throws {
        let carpeta = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try cuerpo(carpeta)
    }

    @Test func nombresDistintosPorUsuario() {
        let a = UUID()
        let b = UUID()
        #expect(ContenedorRico.nombreAlmacen(usuario: a) != ContenedorRico.nombreAlmacen(usuario: b))
        #expect(ContenedorRico.nombreAlmacen(usuario: nil) == "Rico")
        #expect(ContenedorRico.nombreAlmacen(usuario: a) == ContenedorRico.nombreAlmacen(usuario: a))
    }

    @Test func otroUsuarioNoVeLosDatos() throws {
        try conCarpeta { carpeta in
            let a = UUID()
            let b = UUID()
            let contenedorA = try ContenedorRico.crear(usuario: a, carpeta: carpeta)
            let modelo = FichaRapidaModelo(lugar: grelo)
            modelo.estrellas = 4.5
            try modelo.guardar(en: contenedorA.mainContext)
            #expect(try contenedorA.mainContext.fetchCount(FetchDescriptor<Visita>()) == 1)

            let contenedorB = try ContenedorRico.crear(usuario: b, carpeta: carpeta)
            #expect(try contenedorB.mainContext.fetchCount(FetchDescriptor<Visita>()) == 0)
        }
    }

    @Test func elMismoUsuarioRecuperaSusDatos() throws {
        try conCarpeta { carpeta in
            let a = UUID()
            do {
                let contenedorA = try ContenedorRico.crear(usuario: a, carpeta: carpeta)
                let modelo = FichaRapidaModelo(lugar: grelo)
                modelo.estrellas = 4.5
                try modelo.guardar(en: contenedorA.mainContext)
                _ = try ContenedorRico.crear(usuario: UUID(), carpeta: carpeta)
            }
            let otraVez = try ContenedorRico.crear(usuario: a, carpeta: carpeta)
            #expect(try otraVez.mainContext.fetchCount(FetchDescriptor<Visita>()) == 1)
        }
    }
}
