import Foundation

public struct Classification: Equatable, Sendable {
    public let kind: MovementKind
    public let method: PaymentMethod
    /// true si una palabra clave dejó claro el tipo y el método.
    public let explicit: Bool
}

/// Hacia dónde va la plata que se mueve entre una cuenta y sus cajitas o bolsillos.
public enum PocketDirection: String, Sendable {
    /// Se guarda: sale de la cuenta hacia la cajita.
    case toPocket
    /// Se saca: vuelve de la cajita a la cuenta.
    case fromPocket
}

public enum MovementClassifier {
    static let cardPaymentWords = ["pago a tu tarjeta", "pago de tu tarjeta", "abono a tu tarjeta", "pagaste tu tarjeta",
                                   "a tu tarjeta", "a tu credito", "abonamos"]
    static let incomeWords = ["recibiste", "te enviaron", "te transfirieron", "te llego", "te llegaron", "abono",
                              "consignacion", "deposito", "ingreso de", "te pagaron",
                              "reembolso", "devolucion", "reverso", "anulacion"]
    static let refundWords = ["reembolso", "devolucion", "reverso", "reversion", "anulacion"]
    static let llaveWords = ["llave", "bre-b", "breb"]
    static let outgoingTransferWords = ["transferiste", "enviaste", "transferencia"]
    static let purchaseWords = ["compra", "pagaste", "pago"]

    /// Devolución de plata de una compra anterior: resta del gasto, no cuenta como ingreso.
    public static func isRefund(_ text: String) -> Bool {
        let t = TextNormalizer.fold(text)
        return refundWords.contains { t.contains($0) }
    }

    static let pocketWord = try! NSRegularExpression(pattern: #"\b(?:cajitas?|bolsillos?)\b"#)
    static let toPocketWords = ["agregaste", "guardaste", "ahorraste", "moviste", "pasaste", "depositaste"]
    static let fromPocketWords = ["retiraste", "sacaste", "rescataste"]

    /// Plata que se mueve entre la cuenta y una de sus cajitas o bolsillos («Agregaste dinero a tu Cajita…»,
    /// «Retiraste dinero de tu Cajita…»): sigue siendo tuya, así que es un traslado, no un ingreso ni un gasto.
    /// Hace falta el verbo para no confundirla con un comercio que se llame «cajita». Con signo (+ vuelve a la
    /// cuenta, − sale de ella) manda el signo; sin él, el verbo.
    public static func pocketDirection(_ text: String, sign: Character? = nil) -> PocketDirection? {
        let t = TextNormalizer.fold(text)
        guard pocketWord.firstMatch(in: t, range: NSRange(location: 0, length: (t as NSString).length)) != nil else { return nil }
        let from = fromPocketWords.contains { t.contains($0) }
        let to = toPocketWords.contains { t.contains($0) }
        guard from || to else { return nil }
        if sign == "+" { return .fromPocket }
        if sign == "-" { return .toPocket }
        return from ? .fromPocket : .toPocket
    }

    public static func classify(_ text: String) -> Classification {
        let t = TextNormalizer.fold(text)
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(cardPaymentWords) { return Classification(kind: .transferencia, method: .transferencia, explicit: false) }
        if has(incomeWords) { return Classification(kind: .ingreso, method: has(llaveWords) ? .llave : .transferencia, explicit: true) }
        if has(llaveWords) { return Classification(kind: .gasto, method: .llave, explicit: true) }
        if t.range(of: #"\bqr\b"#, options: .regularExpression) != nil { return Classification(kind: .gasto, method: .qr, explicit: true) }
        if t.contains("credito") && (t.contains("tarjeta") || t.contains("tc")) {
            return Classification(kind: .gasto, method: .credito, explicit: true)
        }
        if t.contains("debito") { return Classification(kind: .gasto, method: .debito, explicit: true) }
        if has(outgoingTransferWords) { return Classification(kind: .gasto, method: .transferencia, explicit: true) }
        if has(purchaseWords) { return Classification(kind: .gasto, method: .debito, explicit: false) }
        return Classification(kind: .gasto, method: .debito, explicit: false)
    }
}
