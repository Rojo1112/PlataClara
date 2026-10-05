import SwiftUI
import SwiftData
import PlataCore

struct HomeView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var recurring: [RecurringExpense]
    @Query private var occurrences: [RecurringOccurrence]
    @AppStorage("abrirNuevoMovimiento") private var openNewMovement = false

    var body: some View {
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        let accountSnapshots = accounts.map(\.snapshot)
        let key = RecurringPlanner.monthKey(for: .now, calendar: .gregoriano)
        let pending = RecurringService.pendingTotal(monthKey: key, occurrences: occurrences, recurring: recurring)
        let savings = Set(accounts.filter { $0.kind != .credito }.map(\.id))
        let summary = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: .now, calendar: .gregoriano),
                                    pendingFixed: pending, ownSavingsAccounts: savings)
        let toReview = movements.filter { $0.status == .porRevisar }.count

        NavigationStack {
            List {
                Section {
                    metric("Dinero disponible", Ledger.totalCash(accounts: accountSnapshots, movements: snapshots))
                    metric("Deuda en tarjetas", Ledger.totalDebt(accounts: accountSnapshots, movements: snapshots), .red)
                }
                Section("Este mes") {
                    if summary.totalIn > 0 || summary.totalOut > 0 {
                        Label(summary.overspent
                              ? "Gastaste \(Money.format(summary.deficit)) más de lo que te entró"
                              : "Te sobran \(Money.format(summary.saved)) de lo que te entró",
                              systemImage: summary.overspent ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(summary.overspent ? Color.red : Color.green)
                            .font(.subheadline.weight(.semibold))
                    }
                    metric("Te entró", summary.totalIn, .green)
                    metric("Gastos", summary.grossExpenses)
                    if summary.unregisteredCardSpending > 0 {
                        metric("Pagos a tarjeta", summary.unregisteredCardSpending)
                    }
                    metric("Ahorro", summary.saved, summary.saved < 0 ? .red : .primary)
                    metric("Fijos pendientes", pending, .orange)
                    metric("Ahorro posible", summary.possibleSaving, summary.possibleSaving < 0 ? .red : .green)
                }
                if toReview > 0 {
                    Section {
                        Label("\(toReview) movimiento(s) por revisar", systemImage: "tray.full").foregroundStyle(.orange)
                    }
                }
                Section("Cuentas") {
                    if accounts.isEmpty {
                        NavigationLink("Agrega tu primera cuenta") { AccountsView() }
                    }
                    ForEach(accounts) { account in
                        let balance = Ledger.balance(of: account.snapshot, movements: snapshots)
                        VStack(alignment: .leading, spacing: 2) {
                            metric(account.name, balance, account.kind == .credito ? .red : .primary)
                            if account.kind == .credito, let limit = account.creditLimit, limit > 0 {
                                Text("Cupo disponible: \(Money.format(limit - balance))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PlataClara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { openNewMovement = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: Int, _ color: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Money.format(value)).monospacedDigit().fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
