import Foundation

public enum TextNormalizer {
    public static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_CO")).lowercased()
    }
}
