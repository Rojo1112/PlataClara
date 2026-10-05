import Foundation
import SwiftData
import PlataCore

@Model
final class RecurringExpense {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Int = 0
    var dayOfMonth: Int = 1
    var accountID: UUID?
    var methodRaw: String = PaymentMethod.debito.rawValue
    var categoryID: UUID?
    var active: Bool = true
    var remind: Bool = true

    init(name: String, amount: Int, dayOfMonth: Int) {
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .debito }
        set { methodRaw = newValue.rawValue }
    }

    var snapshot: RecurringSnapshot {
        RecurringSnapshot(id: id, name: name, amount: amount, dayOfMonth: dayOfMonth, accountID: accountID, active: active)
    }
}
