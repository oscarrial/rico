import Foundation

/// Distancia entre dos coordenadas (haversine), sin depender de CoreLocation.
public enum DistanciaGeo {
    public static func metros(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radioTierra = 6_371_000.0
        let rad = Double.pi / 180
        let dLat = (lat2 - lat1) * rad
        let dLon = (lon2 - lon1) * rad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * rad) * cos(lat2 * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radioTierra * atan2(sqrt(a), sqrt(1 - a))
    }
}
