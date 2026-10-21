import Foundation

/// Qué tan confiable es el saldo que muestra la app.
public enum Confidence: Int, Comparable, Sendable {
    case bajo, medio, alto, verificado

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .bajo: return "Confianza baja"
        case .medio: return "Confianza media"
        case .alto: return "Confianza alta"
        case .verificado: return "Verificado con el banco"
        }
    }
}

/// Un arreglo que explicaría una diferencia con el banco. Nunca se aplica solo: la persona lo confirma.
public struct Fix: Equatable, Sendable, Identifiable {
    public enum Action: Hashable, Sendable {
        /// El banco liberó la retención: ese movimiento no llegó a ser un gasto y se borra.
        case releaseHold(UUID)
        /// El movimiento quedó registrado dos veces: se borra la copia.
        case removeDuplicate(UUID)
        /// Está «por revisar» y por eso no cuenta en el saldo: se confirma.
        case confirmPending(UUID)
        /// Plata que se movió desde una cajita (monto positivo) o hacia una cajita (negativo).
        case pocketTransfer(amount: Int, date: Date)
    }

    public let action: Action
    /// Cuánto cambia el saldo calculado de la cuenta si se aplica.
    public let effect: Int
    public let summary: String

    public var id: String {
        switch action {
        case .releaseHold(let id): return "hold-\(id)"
        case .removeDuplicate(let id): return "dup-\(id)"
        case .confirmPending(let id): return "pending-\(id)"
        case .pocketTransfer(let amount, let date): return "pocket-\(amount)-\(date.timeIntervalSince1970)"
        }
    }
}

/// Un tramo de tiempo sin ningún movimiento registrado.
public struct TimeGap: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// El saldo calculado de una cuenta de ahorros baja de cero, cosa que el banco no permite: entró plata que no está registrada.
public struct NegativeDip: Equatable, Sendable {
    /// Primer momento en que el saldo calculado queda en negativo.
    public let firstNegative: Date
    /// Lo mínimo que tuvo que entrar sin estar registrado (lo más negativo que llega a quedar).
    public let shortfall: Int
}

/// Lo que pasó entre un punto de cuadre y el siguiente (o hasta hoy, si es el último).
public struct SegmentAudit: Equatable, Sendable {
    /// nil: desde el saldo inicial de la cuenta.
    public let start: CheckpointSnapshot?
    /// nil: tramo abierto, hasta hoy, sin un saldo del banco para comparar.
    public let end: CheckpointSnapshot?
    public let startBalance: Int
    /// Saldo calculado al final del tramo: el de partida más los movimientos del tramo.
    public let expected: Int
    public let movementCount: Int
    /// Saldo del banco menos el calculado. nil en el tramo abierto.
    public let difference: Int?
    /// Margen por los centavos que se descartan en cada movimiento.
    public let tolerance: Int
    public let dip: NegativeDip?
    public let gaps: [TimeGap]
    /// Combinación de arreglos que suma exactamente la diferencia, si existe.
    public let explanation: [Fix]?
    /// Traslado de cajita que cerraría la diferencia o el saldo negativo.
    public let pocketFix: Fix?

    public var matches: Bool { (difference.map { abs($0) <= tolerance } ?? true) && dip == nil }

    /// Plata que nada explica todavía.
    public var unexplained: Int {
        if matches || explanation != nil { return 0 }
        if let difference, abs(difference) > tolerance { return abs(difference) }
        return dip?.shortfall ?? 0
    }
}

public struct AccountAudit: Equatable, Sendable {
    public let balance: Int
    public let lastCheckpoint: CheckpointSnapshot?
    /// Del más reciente (el abierto, hasta hoy) al más antiguo.
    public let segments: [SegmentAudit]
    public let confidence: Confidence
    public let unexplained: Int
    public let reasons: [String]
}

/// Contrasta lo que dice el banco (los puntos de cuadre) con lo que suman los movimientos y busca qué explica cada diferencia.
public enum BalanceAudit {
    /// Más candidatos que estos y la búsqueda se queda con los más recientes (2^14 combinaciones como mucho).
    public static let maxCandidates = 14
    /// Tolerancia de la búsqueda de combinaciones.
    public static let comboTolerance = 1
    /// Antes del primer movimiento o después del último, un tramo vacío desde una hora ya se muestra.
    public static let edgeGap: TimeInterval = 3_600
    /// Entre dos movimientos, el tramo vacío tiene que ser de al menos un día.
    public static let innerGap: TimeInterval = 86_400

    /// - Parameter allowsPockets: la cuenta tiene cajitas o bolsillos, así que un traslado puede explicar la diferencia.
    public static func audit(account: AccountSnapshot, movements: [MovementSnapshot], checkpoints: [CheckpointSnapshot],
                             now: Date, calendar: Calendar, allowsPockets: Bool = true) -> AccountAudit {
        let own = movements.filter { touches($0, account) }
        let confirmed = own.filter { $0.status == .confirmado }
        let points = checkpoints.filter { $0.accountID == account.id }.sorted { $0.date < $1.date }
        let pockets = allowsPockets && account.kind == .ahorros

        var segments: [SegmentAudit] = []
        if points.count > 1 {
            for i in 0..<(points.count - 1) {
                segments.append(segment(account: account, start: points[i], end: points[i + 1], confirmed: confirmed,
                                        all: own, startBalance: points[i].balance, pockets: pockets))
            }
        }
        let open = segment(account: account, start: points.last, end: nil, confirmed: confirmed, all: own,
                           startBalance: points.last?.balance ?? account.openingBalance, pockets: pockets)
        segments.append(open)
        segments.reverse()

        let lastClosed = segments.count > 1 ? segments[1] : nil
        var reasons: [String] = []
        let confidence: Confidence
        if let dip = open.dip {
            confidence = .bajo
            reasons.append("El saldo calculado queda en negativo desde el \(DateText.dayTime(dip.firstNegative, calendar)): falta al menos \(Money.format(dip.shortfall)) que entró y no está registrado.")
        } else if points.isEmpty {
            confidence = .medio
            reasons.append("Todavía no lo has cuadrado con el banco: el saldo sale del saldo inicial más los movimientos.")
        } else if let closed = lastClosed, !closed.matches {
            confidence = .medio
            if closed.explanation != nil {
                reasons.append("Hay una diferencia con el banco que una propuesta explica: falta que la confirmes.")
            } else if let difference = closed.difference {
                reasons.append("Entre los dos últimos cuadres no cuadran \(Money.format(abs(difference))). El saldo de hoy parte del banco, pero faltan movimientos en ese tramo.")
            }
        } else if let last = points.last, calendar.isDate(last.date, inSameDayAs: now), open.movementCount == 0 {
            confidence = .verificado
        } else {
            confidence = .alto
        }
        let unexplained = open.dip?.shortfall ?? (lastClosed?.unexplained ?? 0)
        return AccountAudit(balance: open.expected, lastCheckpoint: points.last, segments: segments,
                            confidence: confidence, unexplained: unexplained, reasons: reasons)
    }

    // MARK: un tramo

    static func segment(account: AccountSnapshot, start: CheckpointSnapshot?, end: CheckpointSnapshot?,
                        confirmed: [MovementSnapshot], all: [MovementSnapshot], startBalance: Int,
                        pockets: Bool) -> SegmentAudit {
        func inside(_ m: MovementSnapshot) -> Bool {
            (start.map { m.date > $0.date } ?? true) && (end.map { m.date <= $0.date } ?? true)
        }
        // A la misma hora, primero lo que entra: un reembolso y su cobro en el mismo minuto no dan un falso negativo.
        let ms = confirmed.filter(inside).sorted {
            $0.date != $1.date ? $0.date < $1.date : Ledger.effect(of: $0, on: account) > Ledger.effect(of: $1, on: account)
        }
        let expected = ms.reduce(startBalance) { $0 + Ledger.effect(of: $1, on: account) }
        let difference = end.map { $0.balance - expected }
        let tolerance = max(1, ms.count)
        let dip = account.kind == .ahorros ? negativeDip(ms, account: account, startBalance: startBalance) : nil

        var explanation: [Fix]?
        var pocketFix: Fix?
        if let difference, abs(difference) > tolerance {
            let pending = all.filter { $0.status != .confirmado && inside($0) }
            explanation = combination(for: difference, among: candidates(ms, pending: pending, account: account))
            if pockets, let end { pocketFix = pocketTransfer(difference, date: end.date) }
        } else if let dip, pockets {
            pocketFix = pocketTransfer(dip.shortfall, date: dip.firstNegative.addingTimeInterval(-60))
        }

        let isOff = (difference.map { abs($0) > tolerance } ?? false) || dip != nil
        return SegmentAudit(start: start, end: end, startBalance: startBalance, expected: expected,
                            movementCount: ms.count, difference: difference, tolerance: tolerance, dip: dip,
                            gaps: isOff ? gaps(ms.map(\.date), start: start?.date, end: end?.date) : [],
                            explanation: explanation, pocketFix: pocketFix)
    }

    static func negativeDip(_ ms: [MovementSnapshot], account: AccountSnapshot, startBalance: Int) -> NegativeDip? {
        var running = startBalance
        var lowest = startBalance
        var first: Date?
        for m in ms {
            running += Ledger.effect(of: m, on: account)
            if running < 0, first == nil { first = m.date }
            lowest = min(lowest, running)
        }
        guard let first, lowest < 0 else { return nil }
        return NegativeDip(firstNegative: first, shortfall: -lowest)
    }

    /// Tramos sin movimientos: al empezar, al terminar y, en medio, los de un día o más. Los tres más largos.
    static func gaps(_ dates: [Date], start: Date?, end: Date?) -> [TimeGap] {
        let sorted = dates.sorted()
        var result: [TimeGap] = []
        if let start {
            let next = sorted.first ?? end
            if let next, next.timeIntervalSince(start) >= edgeGap { result.append(TimeGap(start: start, end: next)) }
        }
        for (a, b) in zip(sorted, sorted.dropFirst()) where b.timeIntervalSince(a) >= innerGap {
            result.append(TimeGap(start: a, end: b))
        }
        if let end, let last = sorted.last, end.timeIntervalSince(last) >= edgeGap {
            result.append(TimeGap(start: last, end: end))
        }
        return Array(result.sorted { $0.duration > $1.duration }.prefix(3)).sorted { $0.start < $1.start }
    }

    // MARK: combinaciones

    /// Movimientos que, si se arreglan, cambian el saldo calculado: retenciones, copias repetidas y pendientes.
    static func candidates(_ ms: [MovementSnapshot], pending: [MovementSnapshot], account: AccountSnapshot) -> [(date: Date, fix: Fix)] {
        var result: [(date: Date, fix: Fix)] = []
        for m in ms where m.isHold {
            let effect = -Ledger.effect(of: m, on: account)
            result.append((m.date, Fix(action: .releaseHold(m.id), effect: effect,
                                       summary: "Se liberó la retención de \(label(m)) por \(Money.format(m.amount))")))
        }
        var used = Set<UUID>()
        for (i, a) in ms.enumerated() {
            for b in ms[(i + 1)...] where !used.contains(b.id) && !used.contains(a.id) && !b.isHold {
                guard a.amount == b.amount, a.kind == b.kind, a.accountID == b.accountID,
                      a.destinationAccountID == b.destinationAccountID,
                      abs(b.date.timeIntervalSince(a.date)) <= StatementReconciler.timeWindow else { continue }
                used.insert(b.id)
                let effect = -Ledger.effect(of: b, on: account)
                result.append((b.date, Fix(action: .removeDuplicate(b.id), effect: effect,
                                           summary: "\(label(b)) por \(Money.format(b.amount)) está registrado dos veces")))
            }
        }
        for m in pending {
            let effect = Ledger.effect(of: m, on: account)
            guard effect != 0 else { continue }
            result.append((m.date, Fix(action: .confirmPending(m.id), effect: effect,
                                       summary: "Falta confirmar \(label(m)) por \(Money.format(m.amount))")))
        }
        return result.sorted { $0.date > $1.date }
    }

    /// El grupo más pequeño de arreglos que suma la diferencia (±1 peso). Prueba todas las combinaciones de los
    /// `maxCandidates` más recientes; con empate gana la que usa los más recientes.
    static func combination(for difference: Int, among candidates: [(date: Date, fix: Fix)]) -> [Fix]? {
        let pool = Array(candidates.prefix(maxCandidates)).map(\.fix)
        guard !pool.isEmpty else { return nil }
        var best: Int?
        for mask in 1..<(1 << pool.count) {
            if let b = best, mask.nonzeroBitCount >= b.nonzeroBitCount { continue }
            var sum = 0
            for i in pool.indices where mask & (1 << i) != 0 { sum += pool[i].effect }
            if abs(sum - difference) <= comboTolerance { best = mask }
        }
        guard let best else { return nil }
        return pool.indices.filter { best & (1 << $0) != 0 }.map { pool[$0] }
    }

    static func pocketTransfer(_ amount: Int, date: Date) -> Fix {
        Fix(action: .pocketTransfer(amount: amount, date: date), effect: amount,
            summary: amount > 0
                ? "Fue un traslado de \(Money.format(amount)) desde una cajita"
                : "Fue un traslado de \(Money.format(-amount)) hacia una cajita")
    }

    static func touches(_ m: MovementSnapshot, _ account: AccountSnapshot) -> Bool {
        m.accountID == account.id || (m.kind == .transferencia && m.destinationAccountID == account.id)
    }

    private static func label(_ m: MovementSnapshot) -> String {
        let name = (m.merchant ?? "").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? m.kind.displayName.lowercased() : name
    }
}

/// Fechas cortas en español para los textos del núcleo (la app tiene su propio formateador).
enum DateText {
    static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static func dayTime(_ date: Date, _ calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.month, .day, .hour, .minute], from: date)
        func two(_ n: Int?) -> String { n.map { $0 < 10 ? "0\($0)" : "\($0)" } ?? "00" }
        return "\(c.day ?? 1) \(months[(c.month ?? 1) - 1]) a las \(two(c.hour)):\(two(c.minute))"
    }
}
