import Foundation

public enum Deduplicator {
    public static let window: TimeInterval = 600

    /// Mismo monto y tipo, misma cuenta (o una de las dos desconocida), a ≤ 10 minutos.
    public static func duplicate(amount: Int, kind: MovementKind, accountID: UUID?, date: Date,
                                 existing: [MovementSnapshot]) -> UUID? {
        existing.first { m in
            m.amount == amount && m.kind == kind
                && (accountID == nil || m.accountID == nil || m.accountID == accountID)
                && abs(m.date.timeIntervalSince(date)) <= window
        }?.id
    }
}
