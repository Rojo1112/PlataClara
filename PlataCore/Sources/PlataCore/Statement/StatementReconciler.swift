import Foundation

public enum StatementReconciler {
    /// Un renglón del extracto ya está registrado si hay un movimiento con el mismo monto y tipo,
    /// en la misma cuenta (o sin cuenta) y con ≤ 1 día de diferencia.
    public static func isDuplicate(_ entry: StatementEntry, accountID: UUID?, existing: [MovementSnapshot],
                                   calendar: Calendar) -> Bool {
        let entryDay = calendar.startOfDay(for: entry.date)
        return existing.contains { m in
            guard m.amount == entry.amount, m.kind == entry.kind else { return false }
            guard accountID == nil || m.accountID == nil || m.accountID == accountID else { return false }
            let days = calendar.dateComponents([.day], from: entryDay, to: calendar.startOfDay(for: m.date)).day ?? 99
            return abs(days) <= 1
        }
    }
}
