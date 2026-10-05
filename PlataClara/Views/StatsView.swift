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
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var recurring: [RecurringExpense]
    @Query private var occurrences: [RecurringOccurrence]
    @State private var monthOffset = 0

    var body: some View {
        let calendar = Calendar.gregoriano
        let reference = calendar.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
        let month = Stats.monthInterval(containing: reference, calendar: calendar)
        let names = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let snapshots = movements.map { m in m.snapshot(categoryName: m.categoryID.flatMap { names[$0] }) }
        let savings = Set(accounts.filter { $0.kind != .credito }.map(\.id))
        let pending = RecurringService.pendingTotal(monthKey: RecurringPlanner.monthKey(for: reference, calendar: calendar),
                                                    occurrences: occurrences, recurring: recurring)
        let summary = Stats.summary(movements: snapshots, in: month, pendingFixed: pending, ownSavingsAccounts: savings)
        let byCategory = Stats.spendingByCategory(movements: snapshots, in: month)
        let top = Stats.topSpending(movements: snapshots, in: month)
        let byMethod = Stats.expensesByMethod(movements: snapshots, in: month)
        let monthExpenses = movements
            .filter { $0.kind == .gasto && $0.status == .confirmado && month.contains($0.date) && $0.date < month.end }
            .sorted { $0.date > $1.date }
        let history = lastSixMonths(snapshots: snapshots, reference: reference, calendar: calendar, savings: savings)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(Fecha.mesAnio(reference)).font(.headline)
                        Spacer()
                        Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(monthOffset >= 0)
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    verdict(summary)
                }

                Section {
                    row("Ingresos (te pagaron o te enviaron)", summary.income, color: .green)
                    if summary.refunds > 0 {
                        row("Reembolsos de compras", summary.refunds, color: .green)
                    }
                    row("Total que te entró", summary.totalIn, color: .green, bold: true)
                } header: {
                    Text("Lo que te entró")
                } footer: {
                    Text("Es lo mismo que «lo que entró a tu cuenta» en el extracto del banco.")
                }

                Section {
                    row("Gastos (compras y envíos)", summary.grossExpenses)
                    if summary.unregisteredCardSpending > 0 {
                        row("Pagos a tarjeta de crédito", summary.unregisteredCardSpending)
                    }
                    row("Total que te salió", summary.totalOut, color: summary.overspent ? .red : .primary, bold: true)
                } header: {
                    Text("Lo que te salió")
                } footer: {
                    Text(cardFooter(summary))
                }

                Section("Ahorro") {
                    row(summary.saved < 0 ? "Te faltó" : "Ahorro del mes", summary.saved, color: summary.saved < 0 ? .red : .green)
                    if pending > 0 {
                        row("Gastos fijos que faltan por pagar", pending, color: .orange)
                        row("Ahorro posible", summary.possibleSaving, color: summary.possibleSaving < 0 ? .red : .green)
                    }
                    textRow("Tasa de ahorro", summary.totalIn > 0 ? "\(Int((Double(summary.saved) / Double(summary.totalIn) * 100).rounded())) %" : "—")
                    row("Gasto diario promedio",
                        Stats.averageDailyExpense(expenses: summary.outflow, interval: month, today: .now, calendar: calendar))
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
                        ForEach(byCategory, id: \.name) { item in
                            row(item.name, item.amount, detail: percent(item.amount, of: summary.grossExpenses))
                        }
                    }
                }

                if !top.isEmpty {
                    Section {
                        ForEach(top, id: \.name) { item in
                            row(item.name, item.amount, detail: percent(item.amount, of: summary.grossExpenses))
                        }
                        NavigationLink("Ver los \(monthExpenses.count) gastos del mes") {
                            MonthExpensesView(title: Fecha.mesAnio(reference), movements: monthExpenses,
                                              accounts: accounts, categories: categories)
                        }
                    } header: {
                        Text("¿En qué se fue la plata?")
                    } footer: {
                        Text("Gastos sumados por comercio o persona, de mayor a menor.")
                    }
                }

                if !byMethod.isEmpty {
                    Section("Por método de pago") {
                        ForEach(byMethod, id: \.method) { row($0.method.displayName, $0.amount) }
                    }
                }

                Section("Últimos 6 meses") {
                    Chart(history) { bar in
                        BarMark(x: .value("Mes", bar.label), y: .value("Monto", bar.amount))
                            .foregroundStyle(by: .value("Tipo", bar.series))
                            .position(by: .value("Tipo", bar.series))
                    }
                    .chartForegroundStyleScale(["Te entró": Color.green, "Te salió": Color.red])
                    .frame(height: 220)
                }
            }
            .navigationTitle("Estadísticas")
        }
    }

    @ViewBuilder
    private func verdict(_ s: MonthSummary) -> some View {
        if s.totalIn == 0 && s.totalOut == 0 {
            Text("Todavía no hay movimientos este mes.").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(s.overspent
                      ? "Gastaste \(Money.format(s.deficit)) más de lo que te entró"
                      : "Te sobraron \(Money.format(s.saved)) de lo que te entró",
                      systemImage: s.overspent ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(s.overspent ? Color.red : Color.green)
                Text("Te entró \(Money.format(s.totalIn)) · te salió \(Money.format(s.totalOut))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if s.totalIn > 0 {
                    ProgressView(value: Double(min(s.totalOut, s.totalIn)), total: Double(s.totalIn))
                        .tint(s.overspent ? .red : (Double(s.totalOut) / Double(s.totalIn) > 0.85 ? .orange : .green))
                    Text("Usaste el \(Int((Double(s.totalOut) / Double(s.totalIn) * 100).rounded())) % de lo que te entró")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func cardFooter(_ s: MonthSummary) -> String {
        guard s.cardPayments > 0 else {
            return "Gastos con tarjeta débito, crédito, QR, Bre-B y envíos. Los reembolsos ya están descontados."
        }
        if s.unregisteredCardSpending == s.cardPayments {
            return "Lo que pagaste a la tarjeta cuenta como plata que salió, porque las compras de la tarjeta no están registradas en la app. Si importas también el extracto de la tarjeta, verás en qué se usó."
        }
        return "Del pago a la tarjeta solo cuenta \(Money.format(s.unregisteredCardSpending)): el resto cubre compras con crédito que ya están en tus gastos, para no contarlas dos veces."
    }

    private func percent(_ amount: Int, of total: Int) -> String? {
        total > 0 ? "\(Int((Double(amount) / Double(total) * 100).rounded())) %" : nil
    }

    private func row(_ title: String, _ value: Int, color: Color = .secondary, detail: String? = nil, bold: Bool = false) -> some View {
        HStack {
            Text(title).fontWeight(bold ? .semibold : .regular)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            Text(Money.format(value)).monospacedDigit().foregroundStyle(color).fontWeight(bold ? .semibold : .regular)
        }
    }

    private func textRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).monospacedDigit().foregroundStyle(.secondary) }
    }

    private func lastSixMonths(snapshots: [MovementSnapshot], reference: Date, calendar: Calendar, savings: Set<UUID>) -> [MonthBar] {
        (0..<6).reversed().flatMap { back -> [MonthBar] in
            let date = calendar.date(byAdding: .month, value: -back, to: reference) ?? reference
            let s = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: date, calendar: calendar),
                                  pendingFixed: 0, ownSavingsAccounts: savings)
            let label = Fecha.mesCorto(date)
            return [MonthBar(label: label, series: "Te entró", amount: s.totalIn),
                    MonthBar(label: label, series: "Te salió", amount: s.totalOut)]
        }
    }
}

/// Todos los gastos de un mes, del más reciente al más antiguo.
struct MonthExpensesView: View {
    let title: String
    let movements: [Movement]
    let accounts: [Account]
    let categories: [Category]
    @State private var byAmount = false

    var body: some View {
        let sorted = byAmount ? movements.sorted { $0.amount > $1.amount } : movements
        List {
            Section {
                Picker("Orden", selection: $byAmount) {
                    Text("Por fecha").tag(false)
                    Text("Por monto").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section("\(movements.count) gastos · \(Money.format(movements.reduce(0) { $0 + $1.amount }))") {
                ForEach(sorted) { MovementRow(movement: $0, accounts: accounts, categories: categories) }
            }
        }
        .navigationTitle("Gastos de \(title)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
