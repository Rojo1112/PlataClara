import Foundation
import SwiftData
import PlataCore

@Model
final class Movement {
    var id: UUID = UUID()
    var amount: Int = 0
    var date: Date = Date()
    var kindRaw: String = MovementKind.gasto.rawValue
    var methodRaw: String = PaymentMethod.debito.rawValue
    var accountID: UUID?
    var destinationAccountID: UUID?
    var categoryID: UUID?
    var merchant: String?
    var note: String?
    var sourceRaw: String = CaptureSource.manual.rawValue
    var statusRaw: String = MovementStatus.confirmado.rawValue
    var rawText: String?
    var occurrenceID: UUID?

    init(amount: Int, date: Date, kind: MovementKind, method: PaymentMethod, accountID: UUID?,
         source: CaptureSource, status: MovementStatus) {
        self.amount = amount
        self.date = date
        self.kindRaw = kind.rawValue
        self.methodRaw = method.rawValue
        self.accountID = accountID
        self.sourceRaw = source.rawValue
        self.statusRaw = status.rawValue
    }

    var kind: MovementKind {
        get { MovementKind(rawValue: kindRaw) ?? .gasto }
        set { kindRaw = newValue.rawValue }
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .debito }
        set { methodRaw = newValue.rawValue }
    }

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var status: MovementStatus {
        get { MovementStatus(rawValue: statusRaw) ?? .porRevisar }
        set { statusRaw = newValue.rawValue }
    }

    func snapshot(categoryName: String?) -> MovementSnapshot {
        MovementSnapshot(id: id, amount: amount, date: date, kind: kind, method: method, accountID: accountID,
                         destinationAccountID: destinationAccountID, categoryName: categoryName, status: status)
    }
}
