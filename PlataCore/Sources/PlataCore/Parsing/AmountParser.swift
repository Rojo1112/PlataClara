import Foundation

public enum AmountParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"(?:\$|COP)\s*([0-9](?:[0-9.,]*[0-9])?)|([0-9](?:[0-9.,]*[0-9])?)\s*(?:COP|pesos)"#,
        options: [.caseInsensitive])

    /// Primer monto mayor que cero en el texto. Formato colombiano: punto de miles, coma decimal (se descartan centavos).
    public static func firstAmount(in text: String) -> Int? {
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            for group in 1...2 {
                let range = match.range(at: group)
                guard range.location != NSNotFound else { continue }
                if let value = normalize(ns.substring(with: range)), value > 0 { return value }
            }
        }
        return nil
    }

    /// "12.345,67" -> 12345; "1,234.56" -> 1234; "12000" -> 12000.
    public static func normalize(_ raw: String) -> Int? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if let decimals = s.range(of: #",\d{1,2}$"#, options: .regularExpression) {
            s.removeSubrange(decimals)
        } else if let decimals = s.range(of: #"\.\d{1,2}$"#, options: .regularExpression),
                  s.contains(",") || s.filter({ $0 == "." }).count == 1 {
            s.removeSubrange(decimals)
        }
        s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        return Int(s)
    }
}
