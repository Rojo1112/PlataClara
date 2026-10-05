import Foundation

public struct ParsedMovement: Equatable, Sendable {
    public var amount: Int
    public var kind: MovementKind
    public var method: PaymentMethod
    public var merchant: String?
    public var bank: Bank?
    public var last4: String?
    public var isExplicit: Bool

    public init(amount: Int, kind: MovementKind, method: PaymentMethod, merchant: String?, bank: Bank?,
                last4: String?, isExplicit: Bool) {
        self.amount = amount
        self.kind = kind
        self.method = method
        self.merchant = merchant
        self.bank = bank
        self.last4 = last4
        self.isExplicit = isExplicit
    }
}

public enum GenericParser {
    public static func parse(text: String, sender: String? = nil) -> ParsedMovement? {
        guard let amount = AmountParser.firstAmount(in: text) else { return nil }
        let c = MovementClassifier.classify(text)
        return ParsedMovement(amount: amount, kind: c.kind, method: c.method, merchant: merchant(in: text),
                              bank: BankDetector.detect(text: text, sender: sender), last4: last4(in: text),
                              isExplicit: c.explicit)
    }

    static func last4(in text: String) -> String? {
        RegexHelper.firstGroup(#"(?:\*{1,4}|terminada en|termina en|finalizada en|x{2,4})\s?(\d{4})"#,
                               in: TextNormalizer.fold(text))
    }

    /// Texto después de " en " que empieza con letra, hasta "el/con/por/desde/a las", coma, punto o fin.
    static func merchant(in text: String) -> String? {
        let pattern = #"\ben\s+([A-Za-zÁÉÍÓÚÑáéíóúñ][^\n,.]{1,39}?)(?=\s+(?:el|con|por|desde|a las)\b|[,.\n]|$)"#
        guard let raw = RegexHelper.firstGroup(pattern, in: text) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
