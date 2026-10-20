import Foundation

/// Limpia el nombre que llega del datáfono («REST CASA PEPE SL», «SUMUP *CAFE ALAMEDA»)
/// y el de los candidatos de Apple Maps, con las mismas reglas para que se puedan comparar.
public enum LimpiadorComercio {
    /// Pasarelas y prefijos que van delante de un «*».
    static let pasarelas: Set<String> = [
        "sumup", "sum up", "zettle", "izettle", "izt", "ztl", "sq", "square", "stripe",
        "paypal", "pp", "sp", "tpv", "redsys", "mypos", "dojo", "viva", "revolut"
    ]

    /// Formas jurídicas.
    static let formasJuridicas: Set<String> = [
        "sl", "sa", "slu", "sll", "slne", "scp", "cb", "sc", "srl", "sau", "scl"
    ]

    /// Palabras genéricas de restauración que no distinguen un sitio de otro.
    static let genericas: Set<String> = [
        "rest", "rte", "restaurante", "restaurant", "bar", "cafe", "cafeteria"
    ]

    public static func limpiar(_ nombre: String) -> String {
        var texto = nombre
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()

        // «SUMUP *CAFE ALAMEDA» → «cafe alameda». Solo si lo de delante parece una pasarela.
        if let asterisco = texto.lastIndex(of: "*") {
            let antes = texto[..<asterisco].trimmingCharacters(in: .whitespaces)
            let despues = String(texto[texto.index(after: asterisco)...])
            if pasarelas.contains(antes) || antes.count <= 6 {
                texto = despues
            } else {
                texto = antes + " " + despues
            }
        }

        // «s.l.» y «s.l.u.» antes de partir por signos, para no dejar letras sueltas raras.
        texto = texto
            .replacingOccurrences(of: "s.l.u.", with: " slu ")
            .replacingOccurrences(of: "s.l.", with: " sl ")
            .replacingOccurrences(of: "s.a.", with: " sa ")

        let tokens = texto
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
            .filter { token in
                !token.contains(where: \.isNumber)   // números de terminal y referencias
                    && token.count > 1               // letras sueltas («o», «a», restos)
                    && !formasJuridicas.contains(token)
            }

        let sinGenericas = tokens.filter { !genericas.contains($0) }
        // Si solo quedaban palabras genéricas («BAR»), mejor eso que nada.
        let finales = sinGenericas.isEmpty ? tokens : sinGenericas
        return finales.joined(separator: " ")
    }

    static func tokens(_ limpio: String) -> [String] {
        limpio.split(separator: " ").map(String.init)
    }
}
