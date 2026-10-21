import Foundation

/// Qué se busca en «Explorar zona»: para comer, un café o tomar algo.
public enum TipoSitio: String, CaseIterable, Sendable, Hashable {
    case comer
    case cafe
    case copas
}

/// Decide qué lugares de Apple Maps son sitios para comer o beber y cuáles son tiendas.
///
/// Apple Maps mete en «comida» supermercados, ultramarinos, panaderías y tiendas de vino. Primero
/// se filtra por categoría y después por nombre, porque muchas tiendas llegan mal clasificadas.
public enum FiltroSitios {
    /// Valores de `MKPointOfInterestCategory.rawValue`. Aquí sin MapKit para poder probarlo en Linux.
    public enum Categoria {
        public static let restaurante = "MKPOICategoryRestaurant"
        public static let cafe = "MKPOICategoryCafe"
        public static let panaderia = "MKPOICategoryBakery"
        public static let bar = "MKPOICategoryNightlife"
        public static let cerveceria = "MKPOICategoryBrewery"
        public static let bodega = "MKPOICategoryWinery"
        public static let destileria = "MKPOICategoryDistillery"
        public static let tiendaComida = "MKPOICategoryFoodMarket"
    }

    /// Categorías de cada tipo. Las panaderías solo cuentan como café y las bodegas solo como copas.
    public static func categorias(de tipo: TipoSitio) -> [String] {
        switch tipo {
        case .comer: [Categoria.restaurante]
        case .cafe: [Categoria.cafe, Categoria.panaderia]
        case .copas: [Categoria.bar, Categoria.cerveceria, Categoria.bodega, Categoria.destileria]
        }
    }

    public static func categorias(de tipos: Set<TipoSitio>) -> [String] {
        TipoSitio.allCases.filter(tipos.contains).flatMap(categorias(de:))
    }

    /// Lo que puede ser una visita para comer o beber: todo menos las tiendas de comida.
    /// Para el buscador del alta, la captura de pagos y la detección por ubicación.
    public static let restauracion: [String] = [
        Categoria.restaurante, Categoria.cafe, Categoria.panaderia, Categoria.bar,
        Categoria.cerveceria, Categoria.bodega, Categoria.destileria
    ]

    /// `true` si el lugar es un sitio para comer o beber de alguna de esas categorías.
    /// - Parameters:
    ///   - categoria: la de Apple Maps; sin categoría se juzga solo por el nombre.
    ///   - permitidas: categorías aceptadas (`categorias(de:)` o `restauracion`).
    public static func esValido(nombre: String, categoria: String?, permitidas: [String]) -> Bool {
        if let categoria, !permitidas.contains(categoria) { return false }
        return !pareceTienda(nombre)
    }

    // MARK: Nombres de tienda

    /// Palabras que delatan una tienda aunque Apple Maps la ponga como restaurante o café.
    static let palabrasTienda: Set<String> = [
        "supermercado", "supermercados", "hipermercado", "supermarket", "minimarket", "minimercado",
        "ultramarinos", "alimentacion", "alimentaciones", "comestibles", "autoservicio",
        "fruteria", "carniceria", "pescaderia", "charcuteria", "polleria", "casqueria", "queseria",
        "drogueria", "herbolario", "bazar", "kiosco", "quiosco", "estanco",
        "coviran", "condis", "spar", "masymas", "hiperdino"
    ]

    /// Cadenas y expresiones de varias palabras (ya sin tildes y en minúsculas).
    static let frasesTienda: [String] = [
        // «Venta de…» no entra: en el sur es el nombre de muchos restaurantes de carretera.
        "supermercados dia", "dia market", "carrefour express", "carrefour market",
        "bm supermercados", "cash and carry", "tienda de"
    ]

    /// `true` si el nombre parece de una tienda o de un comercio que no es restauración.
    public static func pareceTienda(_ nombre: String) -> Bool {
        let plano = nombre
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
        let tokens = plano
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
        if tokens.contains(where: palabrasTienda.contains) { return true }
        let unido = tokens.joined(separator: " ")
        if frasesTienda.contains(where: { unido.contains($0) || plano.contains($0) }) { return true }
        // Gasolineras, farmacias, súper grandes… ya están en el clasificador de pagos.
        return ClasificadorComercio.esNoRestauracion(LimpiadorComercio.limpiar(nombre))
    }
}
