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

    /// Margen para decir que dos movimientos con hora son el mismo (el aviso, Apple Pay y el banco no marcan la misma hora).
    public static let timeWindow: TimeInterval = 900

    /// Empareja cada renglón con **un solo** movimiento ya registrado: el más cercano en el tiempo, con el mismo
    /// monto, tipo y cuenta (o sin cuenta). Si el renglón trae hora y el movimiento también, el margen es de
    /// 15 minutos; si alguno solo tiene el día, de un día. Cada movimiento se usa una vez, así dos compras iguales
    /// el mismo día no se confunden, y subir dos veces la misma captura nunca duplica nada.
    /// - Returns: índice del renglón → id del movimiento con el que coincide.
    public static func match(_ entries: [StatementEntry], accountID: UUID?, existing: [MovementSnapshot],
                             calendar: Calendar) -> [Int: UUID] {
        struct Pair { let entry: Int; let movement: Int; let distance: TimeInterval }
        var pairs: [Pair] = []
        for (i, entry) in entries.enumerated() {
            for (j, m) in existing.enumerated() {
                guard m.amount == entry.amount, m.kind == entry.kind else { continue }
                guard accountID == nil || m.accountID == nil || m.accountID == accountID else { continue }
                let gap = abs(m.date.timeIntervalSince(entry.date))
                if entry.hasTime && hasClockTime(m.date, calendar) {
                    guard gap <= timeWindow else { continue }
                } else {
                    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date),
                                                       to: calendar.startOfDay(for: m.date)).day ?? 99
                    guard abs(days) <= 1 else { continue }
                }
                pairs.append(Pair(entry: i, movement: j, distance: gap))
            }
        }
        pairs.sort { ($0.distance, $0.entry, $0.movement) < ($1.distance, $1.entry, $1.movement) }
        var usedEntries = Set<Int>(), usedMovements = Set<Int>()
        var result: [Int: UUID] = [:]
        for pair in pairs where !usedEntries.contains(pair.entry) && !usedMovements.contains(pair.movement) {
            usedEntries.insert(pair.entry)
            usedMovements.insert(pair.movement)
            result[pair.entry] = existing[pair.movement].id
        }
        return result
    }

    /// Un movimiento tiene hora real si no está a las 00:00 en punto (así se guardan los que solo traen el día).
    static func hasClockTime(_ date: Date, _ calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (c.hour ?? 0) != 0 || (c.minute ?? 0) != 0 || (c.second ?? 0) != 0
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
