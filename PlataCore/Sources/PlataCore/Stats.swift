import Foundation

public struct MonthSummary: Equatable, Sendable {
    public let income: Int
    public let expenses: Int
    public let pendingFixed: Int

    public init(income: Int, expenses: Int, pendingFixed: Int) {
        self.income = income
        self.expenses = expenses
        self.pendingFixed = pendingFixed
    }

    public var saved: Int { income - expenses }
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

    public static func summary(movements: [MovementSnapshot], in interval: DateInterval, pendingFixed: Int) -> MonthSummary {
        let ms = confirmed(movements, in: interval)
        let income = ms.filter { $0.kind == .ingreso && !$0.isRefund }.reduce(0) { $0 + $1.amount }
        let refunds = ms.filter { $0.kind == .ingreso && $0.isRefund }.reduce(0) { $0 + $1.amount }
        let spent = ms.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amount }
        let expenses = max(0, spent - refunds)
        return MonthSummary(income: income, expenses: expenses, pendingFixed: pendingFixed)
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
