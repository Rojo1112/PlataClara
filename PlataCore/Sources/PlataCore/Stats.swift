import Foundation

public struct MonthSummary: Equatable, Sendable {
    public let income: Int
    public let expenses: Int
    public let pendingFixed: Int
    /// Devoluciones de compras: ya están descontadas de `expenses`.
    public let refunds: Int
    /// Pagos a tarjeta de crédito hechos en el mes.
    public let cardPayments: Int
    /// Parte de los pagos a tarjeta que no está cubierta por compras con crédito registradas en el mes:
    /// cubre compras que no están en la app, así que cuenta como plata que salió.
    public let unregisteredCardSpending: Int

    public init(income: Int, expenses: Int, pendingFixed: Int, refunds: Int = 0,
                cardPayments: Int = 0, unregisteredCardSpending: Int = 0) {
        self.income = income
        self.expenses = expenses
        self.pendingFixed = pendingFixed
        self.refunds = refunds
        self.cardPayments = cardPayments
        self.unregisteredCardSpending = unregisteredCardSpending
    }

    /// Todo lo que salió del bolsillo: gastos más lo pagado a tarjetas por compras no registradas.
    public var outflow: Int { expenses + unregisteredCardSpending }
    public var saved: Int { income - outflow }
    /// true si en el mes salió más plata de la que entró.
    public var overspent: Bool { outflow > income }
    /// Cuánto se gastó de más (0 si no se pasó).
    public var deficit: Int { max(0, outflow - income) }
    /// Gastos antes de descontar reembolsos.
    public var grossExpenses: Int { expenses + refunds }
    /// Todo lo que entró a las cuentas, como lo muestra el banco: ingresos más reembolsos.
    public var totalIn: Int { income + refunds }
    /// Todo lo que salió de las cuentas, como lo muestra el banco: gastos brutos más pagos a tarjeta no registrados.
    public var totalOut: Int { grossExpenses + unregisteredCardSpending }
    public var possibleSaving: Int { saved - pendingFixed }
    public var savingsRate: Double { income > 0 ? Double(saved) / Double(income) : 0 }
}

public struct CategoryTotal: Equatable, Sendable {
    public let name: String
    public let amount: Int
    public init(name: String, amount: Int) { self.name = name; self.amount = amount }
}

public struct MethodTotal: Equatable, Sendable {
    public let method: PaymentMethod
    public let amount: Int
    public init(method: PaymentMethod, amount: Int) { self.method = method; self.amount = amount }
}

public enum Stats {
    public static let uncategorized = "Sin categoría"

    public static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// - Parameter ownSavingsAccounts: cuentas propias que no son tarjeta. Una transferencia hacia una de ellas
    ///   es mover plata entre bolsillos; cualquier otra transferencia se toma como pago a tarjeta.
    public static func summary(movements: [MovementSnapshot], in interval: DateInterval, pendingFixed: Int,
                               ownSavingsAccounts: Set<UUID> = []) -> MonthSummary {
        let ms = confirmed(movements, in: interval)
        let income = ms.filter { $0.kind == .ingreso && !$0.isRefund }.reduce(0) { $0 + $1.amount }
        let refunds = ms.filter { $0.kind == .ingreso && $0.isRefund }.reduce(0) { $0 + $1.amount }
        let spent = ms.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amount }
        let expenses = max(0, spent - refunds)
        let cardPayments = ms.filter { m in
            m.kind == .transferencia && !(m.destinationAccountID.map(ownSavingsAccounts.contains) ?? false)
        }.reduce(0) { $0 + $1.amount }
        let creditPurchases = ms.filter { $0.kind == .gasto && $0.method == .credito }.reduce(0) { $0 + $1.amount }
        return MonthSummary(income: income, expenses: expenses, pendingFixed: pendingFixed,
                            refunds: min(refunds, spent), cardPayments: cardPayments,
                            unregisteredCardSpending: max(0, cardPayments - creditPurchases))
    }

    /// Gastos del mes agrupados por categoría; si un gasto no tiene, se adivina por su descripción.
    public static func spendingByCategory(movements: [MovementSnapshot], in interval: DateInterval) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: expenses(movements, in: interval)) { m in
            m.categoryName ?? AutoCategory.guess(m.merchant) ?? uncategorized
        }
        return grouped
            .map { CategoryTotal(name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.name < $1.name }
    }

    /// A quién o dónde se fue más plata: gastos del mes agrupados por comercio o persona, de mayor a menor.
    public static func topSpending(movements: [MovementSnapshot], in interval: DateInterval, limit: Int = 8) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: expenses(movements, in: interval)) { m -> String in
            let name = (m.merchant ?? m.categoryName ?? uncategorized).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return name.isEmpty ? uncategorized : name
        }
        return grouped
            .map { CategoryTotal(name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.name < $1.name }
            .prefix(limit).map { $0 }
    }

    public static func expensesByCategory(movements: [MovementSnapshot], in interval: DateInterval) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: expenses(movements, in: interval)) { $0.categoryName ?? uncategorized }
        return grouped
            .map { CategoryTotal(name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.name < $1.name }
    }

    public static func expensesByMethod(movements: [MovementSnapshot], in interval: DateInterval) -> [MethodTotal] {
        let grouped = Dictionary(grouping: expenses(movements, in: interval)) { $0.method }
        return grouped
            .map { MethodTotal(method: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.method.rawValue < $1.method.rawValue }
    }

    /// Gasto promedio por día transcurrido del mes (o del mes completo si ya terminó).
    public static func averageDailyExpense(expenses: Int, interval: DateInterval, today: Date, calendar: Calendar = .current) -> Int {
        let totalDays = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 30
        let days: Int
        if today >= interval.end {
            days = totalDays
        } else if today < interval.start {
            days = 1
        } else {
            days = (calendar.dateComponents([.day], from: interval.start, to: today).day ?? 0) + 1
        }
        return expenses / max(days, 1)
    }

    static func confirmed(_ movements: [MovementSnapshot], in interval: DateInterval) -> [MovementSnapshot] {
        movements.filter { $0.status == .confirmado && $0.date >= interval.start && $0.date < interval.end }
    }

    static func expenses(_ movements: [MovementSnapshot], in interval: DateInterval) -> [MovementSnapshot] {
        confirmed(movements, in: interval).filter { $0.kind == .gasto }
    }
}
