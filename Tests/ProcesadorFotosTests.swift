import Testing
import UIKit
import Visitas

@Suite("Procesador de fotos")
struct ProcesadorFotosTests {
    private func jpeg(ancho: CGFloat, alto: CGFloat) -> Data {
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let imagen = UIGraphicsImageRenderer(size: CGSize(width: ancho, height: alto), format: formato).image { contexto in
            UIColor.orange.setFill()
            contexto.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
            UIColor.blue.setFill()
            contexto.fill(CGRect(x: 0, y: 0, width: ancho / 2, height: alto / 2))
        }
        return imagen.jpegData(compressionQuality: 0.9)!
    }

    @Test func reduceGrandeYMiniaturaManteniendoProporcion() throws {
        let resultado = try #require(ProcesadorFotos.procesar(jpeg(ancho: 3000, alto: 2000)))
        let grande = try #require(UIImage(data: resultado.datos))
        let pequena = try #require(UIImage(data: resultado.miniatura))

        let ladoGrande = max(grande.size.width * grande.scale, grande.size.height * grande.scale)
        let ladoPequena = max(pequena.size.width * pequena.scale, pequena.size.height * pequena.scale)
        #expect(ladoGrande <= 2048)
        #expect(ladoPequena <= 600)

        let proporcionGrande = grande.size.width / grande.size.height
        let proporcionPequena = pequena.size.width / pequena.size.height
        #expect(abs(proporcionGrande - 1.5) < 0.01)
        #expect(abs(proporcionPequena - 1.5) < 0.01)
    }

    @Test func noAmpliaUnaFotoPequena() throws {
        let resultado = try #require(ProcesadorFotos.procesar(jpeg(ancho: 400, alto: 300)))
        let grande = try #require(UIImage(data: resultado.datos))
        #expect(Int(grande.size.width * grande.scale) == 400)
    }
}
