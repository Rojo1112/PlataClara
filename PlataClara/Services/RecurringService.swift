import Foundation
import SwiftData
import UserNotifications
import PlataCore

@MainActor
enum RecurringService {
    static var calendar: Calendar { .gregoriano }

    static func refresh(context: ModelContext, now: Date = .now) {
        ensureMonth(containing: now, context: context)
        scheduleReminders(context: context, now: now)
    }

    /// Crea los pendientes del mes para cada fijo activo que aún no lo tenga.
    static func ensureMonth(containing date: Date, context: ModelContext) {
        let key = RecurringPlanner.monthKey(for: date, calendar: calendar)
        let created = Set(context.all(RecurringOccurrence.self).filter { $0.monthKey == key }.map(\.recurringID))
        let due = RecurringPlanner.occurrencesToCreate(month: date, recurring: context.all(RecurringExpense.self).map(\.snapshot),
                                                       alreadyCreated: created, calendar: calendar)
        for item in due {
            context.insert(RecurringOccurrence(recurringID: item.recurringID, monthKey: key, dueDate: item.dueDate))
        }
        if !due.isEmpty { try? context.save() }
    }

    static func pendingTotal(monthKey: String, occurrences: [RecurringOccurrence], recurring: [RecurringExpense]) -> Int {
        let byID = Dictionary(recurring.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return occurrences
            .filter { $0.monthKey == monthKey && $0.status == .pendiente }
            .reduce(0) { total, occurrence in
                guard let item = byID[occurrence.recurringID], item.active else { return total }
                return total + item.amount
            }
    }

    static func markPaid(_ occurrence: RecurringOccurrence, amount: Int, context: ModelContext) {
        guard let recurring = context.all(RecurringExpense.self).first(where: { $0.id == occurrence.recurringID }) else { return }
        let movement = Movement(amount: amount, date: .now, kind: .gasto, method: recurring.method,
                                accountID: recurring.accountID, source: .fijo, status: .confirmado)
        movement.categoryID = recurring.categoryID
        movement.merchant = recurring.name
        movement.occurrenceID = occurrence.id
        context.insert(movement)
        occurrence.status = .pagado
        occurrence.movementID = movement.id
        try? context.save()
        cancelReminder(for: occurrence)
    }

    static func skip(_ occurrence: RecurringOccurrence, context: ModelContext) {
        occurrence.status = .omitido
        try? context.save()
        cancelReminder(for: occurrence)
    }

    /// Vuelve a pendiente. Si el pago lo creó la pantalla de fijos se borra; si vino de otra fuente solo se desenlaza.
    static func reopen(_ occurrence: RecurringOccurrence, context: ModelContext) {
        if let movementID = occurrence.movementID,
           let movement = context.all(Movement.self).first(where: { $0.id == movementID }) {
            if movement.source == .fijo { context.delete(movement) } else { movement.occurrenceID = nil }
        }
        occurrence.status = .pendiente
        occurrence.movementID = nil
        try? context.save()
    }

    /// Si un gasto confirmado coincide con un fijo pendiente del mismo mes, lo marca pagado.
    static func linkIfMatches(_ movement: Movement, context: ModelContext) {
        guard movement.status == .confirmado, movement.kind == .gasto, movement.occurrenceID == nil else { return }
        // El pendiente puede no existir aún (aviso llegó antes de abrir la app ese mes) o ser del mes vecino.
        ensureMonth(containing: movement.date, context: context)
        ensureMonth(containing: movement.date.addingTimeInterval(RecurringPlanner.matchWindow), context: context)
        let recurring = Dictionary(context.all(RecurringExpense.self).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let open = context.all(RecurringOccurrence.self).filter { $0.status == .pendiente }
        let pending = open.compactMap { occ in
            recurring[occ.recurringID].map { PendingOccurrence(id: occ.id, amount: $0.amount, accountID: $0.accountID, dueDate: occ.dueDate) }
        }
        guard let id = RecurringPlanner.matchingPending(for: movement.snapshot(categoryName: nil), pending: pending),
              let occurrence = open.first(where: { $0.id == id }) else { return }
        occurrence.status = .pagado
        occurrence.movementID = movement.id
        movement.occurrenceID = occurrence.id
        if movement.categoryID == nil { movement.categoryID = recurring[occurrence.recurringID]?.categoryID }
        try? context.save()
        cancelReminder(for: occurrence)
    }

    /// Recordatorio a las 9:00 del día de vencimiento para cada fijo pendiente con «recordar» activo.
    static func scheduleReminders(context: ModelContext, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        let occurrences = context.all(RecurringOccurrence.self)
        center.removePendingNotificationRequests(withIdentifiers: occurrences.map { reminderID($0.id) })

        let recurring = Dictionary(context.all(RecurringExpense.self).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let today = calendar.startOfDay(for: now)
        let items: [(id: String, body: String, date: DateComponents)] = occurrences.compactMap { occ in
            guard occ.status == .pendiente, occ.dueDate >= today,
                  let r = recurring[occ.recurringID], r.remind, r.active else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: occ.dueDate)
            components.hour = 9
            return (reminderID(occ.id), "\(r.name): \(Money.format(r.amount)) vence hoy.", components)
        }
        guard !items.isEmpty else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            for item in items {
                let content = UNMutableNotificationContent()
                content.title = "Pago fijo pendiente"
                content.body = item.body
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.date, repeats: false)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    static func reminderID(_ id: UUID) -> String { "fijo-\(id.uuidString)" }

    static func cancelReminder(for occurrence: RecurringOccurrence) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID(occurrence.id)])
    }
}
