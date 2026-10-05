import SwiftUI
import SwiftData
import Charts
import PlataCore

struct MonthBar: Identifiable {
    let id = UUID()
    let label: String
    let series: String
    let amount: Int
}

struct StatsView: View {
    @Query private var movements: [Movement]
    @Query private var categories: [Category]
    @Query private var recurring: [RecurringExpense]
    @Query private var occurrences: [RecurringOccurrence]
    @State private var monthOffset = 0

    var body: some View {
        let calendar = Calendar.current
        let reference = calendar.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
        let month = Stats.monthInterval(containing: reference)
        let names = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let snapshots = movements.map { m in m.snapshot(categoryName: m.categoryID.flatMap { names[$0] }) }
        let pending = RecurringService.pendingTotal(monthKey: RecurringPlanner.monthKey(for: reference, calendar: calendar),
                                                    occurrences: occurrences, recurring: recurring)
        let summary = Stats.summary(movements: snapshots, in: month, pendingFixed: pending)
        let byCategory = Stats.expensesByCategory(movements: snapshots, in: month)
        let byMethod = Stats.expensesByMethod(movements: snapshots, in: month)
        let history = lastSixMonths(snapshots: snapshots, reference: reference, calendar: calendar)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(reference.formatted(.dateTime.month(.wide).year())).font(.headline)
                        Spacer()
                        Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(monthOffset >= 0)
                    }
                    .buttonStyle(.borderless)
                }
                Section("Resumen") {
                    row("Ingresos", Money.format(summary.income))
                    row("Gastos", Money.format(summary.expenses))
                    row("Ahorro", Money.format(summary.saved))
                    row("Ahorro posible", Money.format(summary.possibleSaving))
                    row("Tasa de ahorro", "\(Int((summary.savingsRate * 100).rounded())) %")
                    row("Gasto diario promedio",
                        Money.format(Stats.averageDailyExpense(expenses: summary.expenses, interval: month, today: .now)))
                }
                Section("Gastos por categoría") {
                    if byCategory.isEmpty {
                        Text("Sin gastos este mes").foregroundStyle(.secondary)
                    } else {
                        Chart(byCategory, id: \.name) { item in
                            SectorMark(angle: .value("Monto", item.amount), innerRadius: .ratio(0.55))
                                .foregroundStyle(by: .value("Categoría", item.name))
                        }
                        .frame(height: 220)
                        ForEach(byCategory, id: \.name) { row($0.name, Money.format($0.amount)) }
                    }
                }
                Section("Por método de pago") {
                    ForEach(byMethod, id: \.method) { row($0.method.displayName, Money.format($0.amount)) }
                }
                Section("Últimos 6 meses") {
                    Chart(history) { bar in
                        BarMark(x: .value("Mes", bar.label), y: .value("Monto", bar.amount))
                            .foregroundStyle(by: .value("Tipo", bar.series))
                            .position(by: .value("Tipo", bar.series))
                    }
                    .frame(height: 220)
                }
            }
            .navigationTitle("Estadísticas")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).monospacedDigit().foregroundStyle(.secondary) }
    }

    private func lastSixMonths(snapshots: [MovementSnapshot], reference: Date, calendar: Calendar) -> [MonthBar] {
        (0..<6).reversed().flatMap { back -> [MonthBar] in
            let date = calendar.date(byAdding: .month, value: -back, to: reference) ?? reference
            let s = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: date), pendingFixed: 0)
            let label = date.formatted(.dateTime.month(.abbreviated))
            return [MonthBar(label: label, series: "Ingresos", amount: s.income),
                    MonthBar(label: label, series: "Gastos", amount: s.expenses)]
        }
    }
}
