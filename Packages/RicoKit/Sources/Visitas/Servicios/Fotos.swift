import Foundation
import Photos
import UIKit
import RicoCore

/// Una foto del carrete tomada durante la visita.
public struct FotoCarrete: Identifiable, Sendable, Hashable {
    public let id: String
    public let miniatura: Data
    public let fecha: Date
}

/// Sugiere fotos del carrete por fecha y lugar. Protocolo para poder probar con datos falsos.
@MainActor
public protocol SugeridorFotos {
    var permisoConcedido: Bool { get }
    var permisoSinPedir: Bool { get }
    func pedirPermiso() async -> Bool
    func fotos(desde: Date, hasta: Date, latitud: Double?, longitud: Double?) async -> [FotoCarrete]
    func datosCompletos(id: String) async -> Data?
}

@MainActor
public final class SugeridorFotosCarrete: SugeridorFotos {
    /// Distancia máxima entre la foto y el restaurante.
    let radioMetros = 300.0

    public init() {}

    public var permisoConcedido: Bool {
        let estado = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return estado == .authorized || estado == .limited
    }

    public var permisoSinPedir: Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined
    }

    public func pedirPermiso() async -> Bool {
        let estado = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return estado == .authorized || estado == .limited
    }

    public func fotos(desde: Date, hasta: Date, latitud: Double?, longitud: Double?) async -> [FotoCarrete] {
        guard permisoConcedido else { return [] }

        let opciones = PHFetchOptions()
        opciones.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", desde as NSDate, hasta as NSDate)
        opciones.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        opciones.fetchLimit = 40
        let resultado = PHAsset.fetchAssets(with: .image, options: opciones)
        let assets = resultado.objects(at: IndexSet(integersIn: 0..<resultado.count))

        // Las fotos sin ubicación se mantienen: muchas cámaras no la guardan.
        let cercanas = assets.filter { asset in
            guard let latitud, let longitud, let ubicacion = asset.location else { return true }
            let distancia = DistanciaGeo.metros(latitud, longitud, ubicacion.coordinate.latitude, ubicacion.coordinate.longitude)
            return distancia <= radioMetros
        }

        let elegidas = cercanas.prefix(12).map { (id: $0.localIdentifier, fecha: $0.creationDate ?? desde) }
        var salida: [FotoCarrete] = []
        for foto in elegidas {
            if let miniatura = await Self.miniatura(id: foto.id) {
                salida.append(FotoCarrete(id: foto.id, miniatura: miniatura, fecha: foto.fecha))
            }
        }
        return salida
    }

    public func datosCompletos(id: String) async -> Data? {
        await Self.datos(id: id)
    }

    // Fuera del actor principal: Photos puede llamar a los bloques desde otro hilo.

    nonisolated private static func datos(id: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let opciones = PHImageRequestOptions()
        opciones.deliveryMode = .highQualityFormat
        opciones.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuacion in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opciones) { datos, _, _, _ in
                continuacion.resume(returning: datos)
            }
        }
    }

    nonisolated private static func miniatura(id: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let opciones = PHImageRequestOptions()
        // Con alta calidad y petición asíncrona, el bloque se llama una sola vez.
        opciones.deliveryMode = .highQualityFormat
        opciones.resizeMode = .fast
        opciones.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuacion in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: opciones
            ) { imagen, _ in
                continuacion.resume(returning: imagen?.jpegData(compressionQuality: 0.7))
            }
        }
    }
}

/// Reduce las fotos antes de guardarlas: ocupan el iCloud del usuario.
public enum ProcesadorFotos {
    public struct Resultado: Sendable {
        public let datos: Data
        public let miniatura: Data
    }

    /// Imagen completa a 2048 px como mucho y miniatura a 600 px, en JPEG.
    public static func procesar(_ datos: Data) -> Resultado? {
        guard let imagen = UIImage(data: datos),
              let grande = redimensionar(imagen, ladoMaximo: 2048).jpegData(compressionQuality: 0.8),
              let pequena = redimensionar(imagen, ladoMaximo: 600).jpegData(compressionQuality: 0.7)
        else { return nil }
        return Resultado(datos: grande, miniatura: pequena)
    }

    /// Procesa fuera del hilo principal.
    public static func procesarEnSegundoPlano(_ datos: Data) async -> Resultado? {
        await Task.detached(priority: .userInitiated) { procesar(datos) }.value
    }

    static func redimensionar(_ imagen: UIImage, ladoMaximo: CGFloat) -> UIImage {
        let lado = max(imagen.size.width, imagen.size.height)
        guard lado > ladoMaximo else { return imagen }
        let escala = ladoMaximo / lado
        let tamano = CGSize(width: (imagen.size.width * escala).rounded(), height: (imagen.size.height * escala).rounded())
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
    }
}
