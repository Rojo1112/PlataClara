import Foundation

public enum BankDetector {
    /// Pistas por banco (texto ya sin tildes y en minúsculas). Agregar un banco = agregar una línea.
    static let rules: [(bank: Bank, keys: [String])] = [
        (.nu, ["nubank", "nu.com.co", "nu colombia", "tarjeta nu", "cuenta nu", "cajita nu"]),
        (.lulo, ["lulo bank", "lulobank", "lulo"]),
        (.uala, ["uala"]),
        (.dale, ["dale!", "dale.com.co", "app dale"])
    ]

    public static func detect(text: String, sender: String?) -> Bank? {
        let haystack = TextNormalizer.fold((sender ?? "") + " " + text)
        return rules.first { rule in rule.keys.contains { haystack.contains($0) } }?.bank
    }
}
