import Foundation

enum RegexHelper {
    /// Primer grupo capturado del patrón (sin distinguir mayúsculas), o nil.
    static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: 1))
    }
}
