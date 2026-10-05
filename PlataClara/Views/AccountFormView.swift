import SwiftUI
import SwiftData
import PlataCore

struct AccountFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: Account?

    @State private var name: String
    @State private var bank: Bank
    @State private var kind: AccountKind
    @State private var openingBalance: Int
    @State private var creditLimit: Int
    @State private var cutoffDay: Int
    @State private var paymentDay: Int
    @State private var last4: String
    @State private var walletCardName: String
    @State private var emailSenders: String

    init(account: Account?) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _bank = State(initialValue: account?.bank ?? .nu)
        _kind = State(initialValue: account?.kind ?? .ahorros)
        _openingBalance = State(initialValue: account?.openingBalance ?? 0)
        _creditLimit = State(initialValue: account?.creditLimit ?? 0)
        _cutoffDay = State(initialValue: account?.cutoffDay ?? 1)
        _paymentDay = State(initialValue: account?.paymentDay ?? 15)
        _last4 = State(initialValue: account?.last4Raw ?? "")
        _walletCardName = State(initialValue: account?.walletCardName ?? "")
        _emailSenders = State(initialValue: account?.emailSendersRaw ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta") {
                    TextField("Nombre (ej. Nu ahorros)", text: $name)
                    Picker("Banco", selection: $bank) {
                        ForEach(Bank.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Tipo", selection: $kind) {
                        ForEach(AccountKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    AmountField(title: kind == .credito ? "Deuda actual" : "Saldo actual", value: $openingBalance)
                }
                if kind == .credito {
                    Section("Tarjeta de crédito") {
                        AmountField(title: "Cupo", value: $creditLimit)
                        Stepper("Día de corte: \(cutoffDay)", value: $cutoffDay, in: 1...31)
                        Stepper("Día de pago: \(paymentDay)", value: $paymentDay, in: 1...31)
                    }
                }
                Section {
                    TextField("Últimos 4 dígitos de tarjetas (separados por coma)", text: $last4)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Nombre de la tarjeta en Wallet", text: $walletCardName)
                    TextField("Correos del banco (separados por coma)", text: $emailSenders)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Para el registro automático")
                } footer: {
                    Text("Sirven para saber a qué cuenta va cada aviso del banco o pago con Apple Pay.")
                }
            }
            .navigationTitle(account == nil ? "Nueva cuenta" : "Editar cuenta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let target = account ?? Account(name: name, bank: bank, kind: kind, openingBalance: openingBalance)
        if account == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.bank = bank
        target.kind = kind
        target.openingBalance = openingBalance
        target.creditLimit = kind == .credito ? creditLimit : nil
        target.cutoffDay = kind == .credito ? cutoffDay : nil
        target.paymentDay = kind == .credito ? paymentDay : nil
        target.last4 = Account.splitList(last4)
        let wallet = walletCardName.trimmingCharacters(in: .whitespaces)
        target.walletCardName = wallet.isEmpty ? nil : wallet
        target.emailSenders = Account.splitList(emailSenders)
        try? context.save()
        dismiss()
    }
}
