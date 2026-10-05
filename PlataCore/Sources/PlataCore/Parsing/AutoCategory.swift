import Foundation

/// Adivina la categoría de un gasto por su descripción, para que las estadísticas no queden todas en
/// «Sin categoría» cuando los movimientos vienen de un extracto o de capturas.
/// Las reglas se revisan en orden; las palabras cortas llevan espacios para no coincidir dentro de un nombre.
public enum AutoCategory {
    static let rules: [(category: String, words: [String])] = [
        ("Costos financieros", ["comision", "cuota de manejo", "cuota por avance", "avance", "intereses", "4x1000", " gmf ", "seguro de vida"]),
        ("Envíos y billeteras", ["enviaste a", "transferiste a", "envio a", "nequi", "daviplata", "bre-b", " llave "]),
        ("Transporte", ["uber", "didi", "cabify", "indriver", "taxi", "transmilenio", "tullave", " metro ", "peaje", "gasolina", "terpel", "primax", "parqueadero"]),
        ("Restaurantes", ["rappi", "ifood", "restaurante", "frisby", " kfc ", "mcdonald", "burger", "crepes", "juan valdez", "starbucks", "pizza", "parrilla", "el corral", "domino"]),
        ("Mercado", ["exito", "carulla", "jumbo", " d1 ", " ara ", "olimpica", "oxxo", "isimo", "makro", "surtimax", "minimercado", "fruver", "supermercado"]),
        ("Suscripciones", ["netflix", "spotify", "youtube", "disney", "prime video", "apple.com", "icloud", " hbo ", "max.com", "chatgpt", "openai", "google one", "paramount"]),
        ("Servicios", [" claro ", "movistar", " tigo ", " wom ", " etb ", " enel ", "codensa", "vanti", "acueducto", " epm ", "gas natural"]),
        ("Salud", ["drogueria", "farmacia", "cruz verde", "farmatodo", "colsanitas", " eps ", "clinica", "laboratorio"]),
        ("Compras", ["falabella", "mercadolibre", "mercado libre", "amazon", " temu ", "shein", " zara ", "homecenter", "alkosto", "ktronix", "novaventa", "dafiti"]),
        ("Ocio", [" cine ", "cinemark", "cine colombia", "procinal", "steam", "playstation", " xbox ", " bar ", "discoteca", "boleta"]),
    ]

    public static func guess(_ description: String?) -> String? {
        guard let description, !description.isEmpty else { return nil }
        let words = TextNormalizer.fold(description)
            .map { $0.isLetter || $0.isNumber || ".-".contains($0) ? $0 : " " }
        let text = " " + String(words).split(separator: " ").joined(separator: " ") + " "
        return rules.first { rule in rule.words.contains { text.contains($0) } }?.category
    }
}
