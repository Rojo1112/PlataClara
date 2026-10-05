import Foundation

public struct AccountHint: Equatable, Sendable {
    public let id: UUID
    public let bank: Bank
    public let kind: AccountKind
    public let last4: [String]
    public let walletCardName: String?
    public let emailSenders: [String]

    public init(id: UUID, bank: Bank, kind: AccountKind, last4: [String], walletCardName: String?, emailSenders: [String]) {
        self.id = id
        self.bank = bank
        self.kind = kind
        self.last4 = last4
        self.walletCardName = walletCardName
        self.emailSenders = emailSenders
    }
}

public enum AccountMatcher {
    /// Orden: últimos 4 dígitos → remitente del correo → banco. Si hay varias, desempata por tipo (crédito/ahorros).
    public static func match(bank: Bank?, last4: String?, method: PaymentMethod, sender: String?, hints: [AccountHint]) -> UUID? {
        if let last4, let hint = hints.first(where: { $0.last4.contains(last4) }) { return hint.id }

        var candidates: [AccountHint] = []
        if let sender, !sender.isEmpty {
            let s = TextNormalizer.fold(sender)
            candidates = hints.filter { h in h.emailSenders.contains { !$0.isEmpty && s.contains(TextNormalizer.fold($0)) } }
        }
        if candidates.isEmpty, let bank {
            candidates = hints.filter { $0.bank == bank }
        }
        if candidates.count == 1 { return candidates[0].id }
        let wanted: AccountKind = method == .credito ? .credito : .ahorros
        let byKind = candidates.filter { $0.kind == wanted }
        return byKind.count == 1 ? byKind[0].id : nil
    }

    public static func match(walletCardName: String, hints: [AccountHint]) -> AccountHint? {
        let name = TextNormalizer.fold(walletCardName).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let named = hints.compactMap { h -> (AccountHint, String)? in
            guard let wallet = h.walletCardName.map(TextNormalizer.fold)?.trimmingCharacters(in: .whitespaces),
                  !wallet.isEmpty else { return nil }
            return (h, wallet)
        }
        if let exact = named.first(where: { $0.1 == name }) { return exact.0 }
        let partial = named.filter { $0.1.contains(name) || name.contains($0.1) }
        return partial.count == 1 ? partial[0].0 : nil
    }
}
