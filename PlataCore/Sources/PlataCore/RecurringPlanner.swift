import Foundation

public struct RecurringSnapshot: Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let amount: Int
    public let dayOfMonth: Int
    public let accountID: UUID?
    public let active: Bool

    public init(id: UUID = UUID(), name: String, amount: Int, dayOfMonth: Int, accountID: UUID?, active: Bool) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.accountID = accountID
        self.active = active
    }
}

public struct DueOccurrence: Equatable, Sendable {
    public let recurringID: UUID
    public let dueDate: Date
    public init(recurringID: UUID, dueDate: Date) { self.recurringID = recurringID; self.dueDate = dueDate }
}

public struct PendingOccurrence: Equatable, Sendable {
    public let id: UUID
    public let amount: Int
    public let accountID: UUID?
    public let dueDate: Date

    public init(id: UUID = UUID(), amount: Int, accountID: UUID?, dueDate: Date) {
        self.id = id
        self.amount = amount
        self.accountID = accountID
        self.dueDate = dueDate
    }
}

public enum RecurringPlanner {
    public static let matchWindow: TimeInterval = 5 * 86_400

    public static func monthKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// Vencimiento a medianoche; el día 31 en un mes más corto cae en el último día.
    public static func dueDate(day: Int, inMonthOf date: Date, calendar: Calendar) -> Date {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 28
        let clamped = min(max(day, 1), daysInMonth)
        return calendar.date(byAdding: .day, value: clamped - 1, to: first)!
    }

    public static func occurrencesToCreate(month: Date, recurring: [RecurringSnapshot], alreadyCreated: Set<UUID>,
                                           calendar: Calendar) -> [DueOccurrence] {
        recurring
            .filter { $0.active && !alreadyCreated.contains($0.id) }
            .map { DueOccurrence(recurringID: $0.id, dueDate: dueDate(day: $0.dayOfMonth, inMonthOf: month, calendar: calendar)) }
    }

    /// Fijo pendiente que corresponde a este gasto: monto ±10 %, misma cuenta (si ambas se conocen), ≤ 5 días del vencimiento.
    public static func matchingPending(for movement: MovementSnapshot, pending: [PendingOccurrence]) -> UUID? {
        guard movement.kind == .gasto else { return nil }
        let candidates = pending.filter { p in
            if let a = p.accountID, let b = movement.accountID, a != b { return false }
            let tolerance = max(p.amount / 10, 1)
            guard abs(movement.amount - p.amount) <= tolerance else { return false }
            return abs(movement.date.timeIntervalSince(p.dueDate)) <= matchWindow
        }
        return candidates.min { abs($0.amount - movement.amount) < abs($1.amount - movement.amount) }?.id
    }
}
