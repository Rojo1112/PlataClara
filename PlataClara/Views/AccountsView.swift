import SwiftUI
import SwiftData
import PlataCore

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]
    @State private var creating = false
    @State private var editing: Account?
    @State private var blockedDelete = false

    var body: some View {
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        List {
            ForEach(accounts) { account in
                Button { editing = account } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.name).font(.headline)
                            Text("\(account.bank.displayName) · \(account.kind.displayName)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(Ledger.balance(of: account.snapshot, movements: snapshots)))
                            .monospacedDigit()
                            .foregroundStyle(account.kind == .credito ? Color.red : Color.primary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView("Sin cuentas", systemImage: "creditcard",
                                       description: Text("Agrega tus cuentas de Nu, Dale!, Ualá o Lulo Bank."))
            }
        }
        .navigationTitle("Cuentas")
        .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $creating) { AccountFormView(account: nil) }
        .sheet(item: $editing) { AccountFormView(account: $0) }
        .alert("No se puede eliminar", isPresented: $blockedDelete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Esta cuenta tiene movimientos. Bórralos o cámbialos de cuenta antes.")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let account = accounts[index]
            let inUse = movements.contains { $0.accountID == account.id || $0.destinationAccountID == account.id }
            if inUse { blockedDelete = true } else { context.delete(account) }
        }
        try? context.save()
    }
}
