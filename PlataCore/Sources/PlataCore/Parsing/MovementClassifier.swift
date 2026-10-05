import Foundation

public struct Classification: Equatable, Sendable {
    public let kind: MovementKind
    public let method: PaymentMethod
    /// true si una palabra clave dejó claro el tipo y el método.
    public let explicit: Bool
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
