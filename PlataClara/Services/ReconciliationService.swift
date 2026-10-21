import Foundation
import SwiftData
import PlataCore

/// Puntos de cuadre, cajitas y arreglos propuestos por el cuadre automático. Nada se aplica sin que la persona lo confirme.
@MainActor
enum ReconciliationService {
    /// Las cajitas ligadas a la cuenta. Si no existen, se crean (empiezan en cero hasta que se cuadren).
    static func pockets(of account: Account, context: ModelContext) -> Account {
        if let existing = context.all(Account.self).first(where: { $0.parentAccountID == account.id }) { return existing }
        let pockets = Account(name: "Cajitas \(account.bank.displayName)", bank: account.bank, kind: .ahorros, openingBalance: 0)
        pockets.parentAccountID = account.id
        context.insert(pockets)
        return pockets
    }

    /// Guarda el saldo del banco. Si ya había un punto a la misma hora (el mismo extracto importado dos veces), lo reemplaza.
    static func addCheckpoint(accountID: UUID, balance: Int, date: Date, source: CheckpointSource, context: ModelContext) {
        context.all(BalanceCheckpoint.self)
            .filter { $0.accountID == accountID && abs($0.date.timeIntervalSince(date)) < 1 }
            .forEach { context.delete($0) }
        context.insert(BalanceCheckpoint(accountID: accountID, date: date, balance: balance, source: source))
        try? context.save()
    }

    static func apply(_ fix: Fix, to account: Account, context: ModelContext) {
        let movements = context.all(Movement.self)
        switch fix.action {
        case .releaseHold(let id), .removeDuplicate(let id):
            if let movement = movements.first(where: { $0.id == id }) { MovementStore.delete(movement, context: context) }
        case .confirmPending(let id):
            guard let movement = movements.first(where: { $0.id == id }) else { return }
            movement.status = .confirmado
            try? context.save()
            MovementStore.didConfirm(movement, context: context)
        case .pocketTransfer(let amount, let date):
            let pockets = pockets(of: account, context: context)
            let fromPockets = amount > 0
            let movement = Movement(amount: abs(amount), date: date, kind: .transferencia, method: .transferencia,
                                    accountID: fromPockets ? pockets.id : account.id, source: .manual, status: .confirmado)
            movement.destinationAccountID = fromPockets ? account.id : pockets.id
            movement.merchant = fromPockets ? "Traslado desde cajitas" : "Traslado a cajitas"
            context.insert(movement)
            try? context.save()
        }
    }

    /// Una cuenta tiene cajitas o bolsillos si es de ahorros, no es efectivo y no es ella misma una cajita.
    static func allowsPockets(_ account: Account) -> Bool {
        account.kind == .ahorros && account.bank != .efectivo && account.parentAccountID == nil
    }

    static func audit(_ account: Account, movements: [MovementSnapshot], checkpoints: [CheckpointSnapshot]) -> AccountAudit {
        BalanceAudit.audit(account: account.snapshot, movements: movements, checkpoints: checkpoints, now: .now,
                           calendar: .gregoriano, allowsPockets: allowsPockets(account))
    }
}
