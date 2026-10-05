import Foundation
import SwiftData
import PlataCore

@Model
final class RecurringOccurrence {
    var id: UUID = UUID()
    var recurringID: UUID = UUID()
    var monthKey: String = ""
    var dueDate: Date = Date()
    var statusRaw: String = OccurrenceStatus.pendiente.rawValue
    var movementID: UUID?

    init(recurringID: UUID, monthKey: String, dueDate: Date) {
        self.recurringID = recurringID
        self.monthKey = monthKey
        self.dueDate = dueDate
    }

    var status: OccurrenceStatus {
        get { OccurrenceStatus(rawValue: statusRaw) ?? .pendiente }
        set { statusRaw = newValue.rawValue }
    }
}
