import Foundation
import SwiftData
import PlataCore

enum CaptureOutcome {
    case registered(Movement)
    case review(Movement)
    case duplicate

    var message: String {
        switch self {
        case .registered(let m):
            return "Registrado: \(m.kind.displayName.lowercased()) de \(Money.format(m.amount)) (\(m.method.displayName))."
        case .review(let m):
            return m.amount > 0 ? "Quedó por revisar: \(Money.format(m.amount))." : "No entendí el aviso; quedó por revisar."
        case .duplicate:
            return "Ese movimiento ya estaba registrado."
        }
    }
}

@MainActor
enum CaptureService {
    static func ingestText(_ text: String, sender: String?, source: CaptureSource, date: Date = .now,
                           context: ModelContext) -> CaptureOutcome {
        let parsed = GenericParser.parse(text: text, sender: sender)
        let hints = context.all(Account.self).map(\.hint)
        let accountID = parsed.flatMap {
            AccountMatcher.match(bank: $0.bank, last4: $0.last4, method: $0.method, sender: sender, hints: hints)
        }
        return store(parsed: parsed, accountID: accountID, rawText: text, source: source, date: date, context: context)
    }

    static func ingestApplePay(amount: String, merchant: String, card: String, date: Date = .now,
                               context: ModelContext) -> CaptureOutcome {
        let hints = context.all(Account.self).map(\.hint)
        let result = ApplePayInput.parse(amount: amount, merchant: merchant, cardName: card, hints: hints)
        let raw = "Apple Pay · \(amount) · \(merchant) · \(card)"
        return store(parsed: result?.movement, accountID: result?.accountID, rawText: raw, source: .applePay,
                     date: date, context: context)
    }

    /// Registra el movimiento y, como pasa solo, avisa con una notificación cuánto fue.
    static func store(parsed: ParsedMovement?, accountID: UUID?, rawText: String, source: CaptureSource,
                      date: Date, context: ModelContext) -> CaptureOutcome {
        let outcome = persist(parsed: parsed, accountID: accountID, rawText: rawText, source: source, date: date, context: context)
        PaymentNotifier.notify(outcome, source: source, context: context)
        return outcome
    }

    private static func persist(parsed: ParsedMovement?, accountID: UUID?, rawText: String, source: CaptureSource,
                              date: Date, context: ModelContext) -> CaptureOutcome {
        let since = date.addingTimeInterval(-86_400)
        let recentMovements = (try? context.fetch(FetchDescriptor<Movement>(predicate: #Predicate { $0.date >= since }))) ?? []
        let recent = recentMovements.map { $0.snapshot(categoryName: nil) }

        switch CapturePipeline.decide(parsed: parsed, accountID: accountID, date: date, existing: recent) {
        case .duplicateOf(let id):
            // Se fusiona con el primero: si ese no tenía cuenta y este sí, hereda cuenta y texto.
            if let first = recentMovements.first(where: { $0.id == id }) {
                if first.accountID == nil, let accountID {
                    first.accountID = accountID
                    if let parsed, parsed.isExplicit { first.status = .confirmado }
                }
                if first.merchant == nil { first.merchant = parsed?.merchant }
                first.rawText = [first.rawText, rawText].compactMap { $0 }.joined(separator: "\n---\n")
                try? context.save()
                if first.status == .confirmado { MovementStore.didConfirm(first, context: context) }
            }
            return .duplicate
        case .unreadable:
            let movement = Movement(amount: 0, date: date, kind: .gasto, method: .debito, accountID: nil,
                                    source: source, status: .porRevisar)
            movement.rawText = rawText
            context.insert(movement)
            try? context.save()
            return .review(movement)
        case .create(let status):
            guard let parsed else { return .duplicate }
            let movement = Movement(amount: parsed.amount, date: date, kind: parsed.kind, method: parsed.method,
                                    accountID: accountID, source: source, status: status)
            movement.merchant = parsed.merchant
            movement.rawText = rawText
            context.insert(movement)
            try? context.save()
            if status == .confirmado {
                MovementStore.didConfirm(movement, context: context)
                return .registered(movement)
            }
            return .review(movement)
        }
    }
}
