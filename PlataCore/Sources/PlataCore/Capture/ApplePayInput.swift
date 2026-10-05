import Foundation

public struct ApplePayResult: Equatable, Sendable {
    public let movement: ParsedMovement
    public let accountID: UUID?
}

public enum ApplePayInput {
    /// Datos del disparador «Transacción» de Atajos. El monto puede venir como "$50.000,00", "COP 12.000" o "12000".
    public static func parse(amount: String, merchant: String, cardName: String, hints: [AccountHint]) -> ApplePayResult? {
        guard let value = AmountParser.firstAmount(in: amount) ?? AmountParser.normalize(amount), value > 0 else { return nil }
        let hint = AccountMatcher.match(walletCardName: cardName, hints: hints)
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        let movement = ParsedMovement(amount: value, kind: .gasto, method: hint?.kind == .credito ? .credito : .debito,
                                      merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant, bank: hint?.bank,
                                      last4: nil, isExplicit: true)
        return ApplePayResult(movement: movement, accountID: hint?.id)
    }
}
