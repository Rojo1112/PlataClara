import Foundation

/// Búsqueda en la lista de movimientos.
public enum MovementSearch {
    /// Cada palabra de la búsqueda debe estar en alguno de los textos (comercio, nota, categoría, cuenta), sin
    /// distinguir mayúsculas ni tildes. Una palabra que es un número («3500», «3.500», «$3.500») busca también en el monto.
    public static func matches(query: String, texts: [String?], amount: Int) -> Bool {
        let words = TextNormalizer.fold(query).split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return true }
        let haystack = TextNormalizer.fold(texts.compactMap { $0 }.joined(separator: " "))
        let amountDigits = String(amount)
        return words.allSatisfy { word in
            if haystack.contains(word) { return true }
            let digits = word.filter(\.isNumber)
            let isNumber = !digits.isEmpty && word.allSatisfy { $0.isNumber || "$.,".contains($0) }
            return isNumber && amountDigits.contains(digits)
        }
    }
}
