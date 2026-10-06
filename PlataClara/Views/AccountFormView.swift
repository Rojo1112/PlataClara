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
    @State private var realBalance = 0
    @Query private var movements: [Movement]

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
                if account == nil {
                    Section {
                        Menu {
                            ForEach(Self.templates, id: \.name) { template in
                                Button(template.name) { apply(template) }
                            }
                        } label: {
                            Label("Elegir una plantilla…", systemImage: "wand.and.stars")
                        }
                    } header: {
                        Text("Empezar rápido")
                    } footer: {
                        Text("Llena el banco y el tipo por ti. Después solo pones el saldo.")
                    }
                }
                Section {
                    TextField("Nombre (ej. Nu ahorros)", text: $name)
                    Picker("Banco", selection: $bank) {
                        ForEach(Bank.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("Tipo", selection: $kind) {
                        ForEach(AccountKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                    AmountField(title: kind == .credito ? "Deuda actual" : "Saldo actual", value: $openingBalance)
                } header: {
                    Text("Cuenta")
                } footer: {
                    if account == nil {
                        Text(kind == .credito
                             ? "Pon lo que debes hoy en la tarjeta, no el cupo."
                             : "Pon lo que tienes hoy en la cuenta. Si vas a importar el extracto de un mes completo, pon el saldo con el que empezó ese mes (lo dice el extracto).")
                    }
                }
                if kind == .credito {
                    Section("Tarjeta de crédito") {
                        AmountField(title: "Cupo", value: $creditLimit)
                        Picker("Día de corte", selection: $cutoffDay) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.menu)
                        Picker("Día de pago", selection: $paymentDay) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.menu)
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
                    Text("Sirven para saber a qué cuenta va cada aviso del banco o pago con Apple Pay. El nombre de Wallet es el que ves al tocar la tarjeta en la app Wallet; debe ser igual.")
                }
                if let account {
                    Section {
                        LabeledContent("La app calcula", value: Money.format(calculatedBalance(account)))
                        AmountField(title: kind == .credito ? "Deuda real hoy en el banco" : "Saldo real hoy en el banco", value: $realBalance)
                        Button("Cuadrar con el banco") { reconcile(account) }
                    } header: {
                        Text("Cuadrar con el banco")
                    } footer: {
                        Text("Escribe lo que muestra tu banco hoy. La app ajusta el saldo inicial para que su cálculo coincida, sin tocar ningún movimiento.")
                    }
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

    /// Combinaciones frecuentes para no escribir nombre, banco y tipo a mano.
    static let templates: [(name: String, bank: Bank, kind: AccountKind)] = [
        ("Nu · Cuenta de ahorros", .nu, .ahorros), ("Nu · Tarjeta de crédito", .nu, .credito),
        ("Dale! · Cuenta de ahorros", .dale, .ahorros),
        ("Ualá · Cuenta de ahorros", .uala, .ahorros), ("Ualá · Tarjeta de crédito", .uala, .credito),
        ("Lulo Bank · Cuenta de ahorros", .lulo, .ahorros), ("Lulo Bank · Tarjeta de crédito", .lulo, .credito),
        ("Efectivo", .efectivo, .ahorros),
    ]

    private func apply(_ template: (name: String, bank: Bank, kind: AccountKind)) {
        name = template.name.replacingOccurrences(of: " · ", with: " ")
        bank = template.bank
        kind = template.kind
    }

    /// Saldo que calcula la app con el saldo inicial que está escrito en el formulario.
    private func calculatedBalance(_ account: Account) -> Int {
        let snapshot = AccountSnapshot(id: account.id, kind: kind, openingBalance: openingBalance)
        return Ledger.balance(of: snapshot, movements: movements.map { $0.snapshot(categoryName: nil) })
    }

    /// Cambia el saldo inicial para que el cálculo de la app sea igual al saldo real del banco.
    private func reconcile(_ account: Account) {
        let movementsEffect = calculatedBalance(account) - openingBalance
        openingBalance = realBalance - movementsEffect
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
