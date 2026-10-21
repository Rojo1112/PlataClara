import Foundation
import SwiftData
import PlataCore

/// Punto de cuadre: el saldo que mostró el banco en una fecha y hora. El saldo de la cuenta parte del último.
@Model
final class BalanceCheckpoint {
    var id: UUID = UUID()
    var accountID: UUID = UUID()
    var date: Date = Date()
    var balance: Int = 0
    var sourceRaw: String = CheckpointSource.manual.rawValue

    init(accountID: UUID, date: Date, balance: Int, source: CheckpointSource) {
        self.accountID = accountID
        self.date = date
        self.balance = balance
        self.sourceRaw = source.rawValue
    }

    var source: CheckpointSource {
        get { CheckpointSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var snapshot: CheckpointSnapshot {
        CheckpointSnapshot(id: id, accountID: accountID, date: date, balance: balance, source: source)
    }
}
