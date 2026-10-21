import SwiftUI
import SwiftData
import PlataCore

struct HomeView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var recurring: [RecurringExpense]
    @Query private var occurrences: [RecurringOccurrence]
    @Query private var checkpoints: [BalanceCheckpoint]
    @AppStorage("abrirNuevoMovimiento") private var openNewMovement = false
    @AppStorage(PaymentNotifier.lastApplePayKey) private var lastApplePay: Double = 0
    @AppStorage("ocultarAvisoApplePay") private var hideApplePayTip = false

    var body: some View {
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        let accountSnapshots = accounts.map(\.snapshot)
        let points = checkpoints.map(\.snapshot)
        let key = RecurringPlanner.monthKey(for: .now, calendar: .gregoriano)
        let pending = RecurringService.pendingTotal(monthKey: key, occurrences: occurrences, recurring: recurring)
        let savings = Set(accounts.filter { $0.kind != .credito }.map(\.id))
        let summary = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: .now, calendar: .gregoriano),
                                    pendingFixed: pending, ownSavingsAccounts: savings)
        let toReview = movements.filter { $0.status == .porRevisar }.count

        NavigationStack {
            List {
                if lastApplePay == 0, !hideApplePayTip, !accounts.isEmpty {
                    Section {
                        NavigationLink {
                            ApplePaySetupView()
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Activa el registro automático de Apple Pay").font(.subheadline.weight(.semibold))
                                    Text("30 segundos, una sola vez. Cada pago te llega con su monto.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "bolt.badge.automatic.fill").foregroundStyle(.orange) }
                        }
                        Button("Ahora no") { hideApplePayTip = true }.font(.caption)
                    }
                }
                Section {
                    metric("Dinero disponible", Ledger.totalCash(accounts: accountSnapshots, movements: snapshots, checkpoints: points))
                    metric("Deuda en tarjetas", Ledger.totalDebt(accounts: accountSnapshots, movements: snapshots, checkpoints: points), .red)
                }
                Section("Este mes") {
                    if summary.totalIn > 0 || summary.totalOut > 0 {
                        Label(summary.overspent
                              ? "Este mes salió \(Money.format(summary.deficit)) más de lo que entró"
                              : "Te sobran \(Money.format(summary.saved)) de lo que te entró",
                              systemImage: summary.overspent ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(summary.overspent ? Color.orange : Color.green)
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
                    // Las cajitas no van aparte: se suman a su cuenta, con el desglose debajo.
                    ForEach(accounts.filter { $0.parentAccountID == nil }) { account in
                        let audit = ReconciliationService.audit(account, movements: snapshots, checkpoints: points)
                        let pockets = accounts.first { $0.parentAccountID == account.id }
                        let inPockets = pockets.map { Ledger.balance(of: $0.snapshot, movements: snapshots, checkpoints: points) }
                        let balance = audit.balance + (inPockets ?? 0)
                        NavigationLink {
                            ReconciliationView(account: account)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                metric(account.name, balance, account.kind == .credito ? .red : .primary)
                                if let inPockets {
                                    Text("En la cuenta \(Money.format(audit.balance)) · en cajitas \(Money.format(inPockets))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if account.kind == .credito, let limit = account.creditLimit, limit > 0 {
                                    Text("Cupo disponible: \(Money.format(limit - balance))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text(statusLine(audit))
                                    .font(.caption).foregroundStyle(ConfidenceLabel(confidence: audit.confidence).color)
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

    /// «Confianza media · cuadrado el 1 mar · falta explicar $ 20.000».
    private func statusLine(_ audit: AccountAudit) -> String {
        var parts = [audit.confidence.title]
        parts.append(audit.lastCheckpoint.map { "cuadrado el \(Fecha.diaMes($0.date))" } ?? "sin cuadrar con el banco")
        if audit.unexplained > 0 { parts.append("falta explicar \(Money.format(audit.unexplained))") }
        return parts.joined(separator: " · ")
    }

    private func metric(_ title: String, _ value: Int, _ color: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Money.format(value)).monospacedDigit().fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
