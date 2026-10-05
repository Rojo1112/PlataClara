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

    /// Compara lo leído con los totales que el extracto declara. La tolerancia es 1 peso por movimiento,
    /// porque se descartan los centavos de cada uno.
    public static func check(entries: [StatementEntry], against totals: StatementTotals) -> TotalsCheck {
        let readIncome = entries.filter { $0.kind == .ingreso }.reduce(0) { $0 + $1.amount }
        let readOutflow = entries.filter { $0.kind != .ingreso }.reduce(0) { $0 + $1.amount }
        let tolerance = max(entries.count, 1)
        return TotalsCheck(
            incomeMatches: totals.income.map { abs(readIncome - $0) <= tolerance },
            outflowMatches: totals.outflow.map { abs(readOutflow - $0) <= tolerance },
            readIncome: readIncome, readOutflow: readOutflow)
    }
}

public struct StatementTotals: Equatable, Sendable {
    public let income: Int?
    public let outflow: Int?

    public init(income: Int?, outflow: Int?) {
        self.income = income
        self.outflow = outflow
    }
}

public struct TotalsCheck: Equatable, Sendable {
    public let incomeMatches: Bool?
    public let outflowMatches: Bool?
    public let readIncome: Int
    public let readOutflow: Int

    public init(incomeMatches: Bool?, outflowMatches: Bool?, readIncome: Int, readOutflow: Int) {
        self.incomeMatches = incomeMatches
        self.outflowMatches = outflowMatches
        self.readIncome = readIncome
        self.readOutflow = readOutflow
    }
}
