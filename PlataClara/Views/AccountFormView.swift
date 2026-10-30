import SwiftUI
import SwiftData
import PlataCore

struct AccountFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var movements: [Movement]
    @Query private var checkpoints: [BalanceCheckpoint]
    let account: Account?

    @State private var name: String
    @State private var bank: Bank
    @State private var kind: AccountKind
    /// Lo que la persona escribe como saldo (o deuda) de hoy.
    @State private var openingBalance: Int
    /// Saldo que calculaba la app al abrir el formulario de una cuenta existente: si cambia, se guarda un punto de cuadre.
    @State private var currentBalance: Int?
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
                    Text((kind == .credito ? "Pon lo que debes hoy en la tarjeta, no el cupo. " : "Pon lo que tienes hoy en la cuenta, como lo muestra el banco. ")
                         + (account == nil
                            ? "Se guarda con la hora de ahora: los movimientos anteriores que importes después no lo cambian."
                            : "Si lo cambias, se guarda como punto de cuadre con la hora de ahora: el saldo parte de ahí y suma solo lo posterior."))
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
                        NavigationLink("Cuadrar con el banco") { ReconciliationView(account: account) }
                    } footer: {
                        Text("Guarda el saldo que muestra el banco con su fecha y hora, o léelo de una captura de la pantalla de inicio. Desde ahí la app suma solo lo posterior y te dice qué falta.")
                    }
                }
            }
            .navigationTitle(account == nil ? "Nueva cuenta" : "Editar cuenta")
            .onAppear {
                // En una cuenta existente el campo muestra el saldo de hoy, no el saldo inicial guardado.
                guard let account, currentBalance == nil else { return }
                let today = Ledger.balance(of: account.snapshot, movements: movements.map { $0.snapshot(categoryName: nil) },
                                           checkpoints: checkpoints.map(\.snapshot))
                currentBalance = today
                openingBalance = today
            }
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

    private func save() {
        let target = account ?? Account(name: name, bank: bank, kind: kind, openingBalance: openingBalance)
        if account == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.bank = bank
        target.kind = kind
        // El saldo escrito es el de hoy. En una cuenta nueva también es el inicial; en una existente el inicial no se toca
        // (es lo que había antes de todos sus movimientos) y el cambio queda como punto de cuadre.
        if account == nil {
            target.openingBalance = openingBalance
        }
        let changed = account == nil ? openingBalance != 0 : openingBalance != currentBalance
        target.creditLimit = kind == .credito ? creditLimit : nil
        target.cutoffDay = kind == .credito ? cutoffDay : nil
        target.paymentDay = kind == .credito ? paymentDay : nil
        target.last4 = Account.splitList(last4)
        let wallet = walletCardName.trimmingCharacters(in: .whitespaces)
        target.walletCardName = wallet.isEmpty ? nil : wallet
        target.emailSenders = Account.splitList(emailSenders)
        try? context.save()
        if changed {
            ReconciliationService.addCheckpoint(accountID: target.id, balance: openingBalance, date: .now, source: .manual, context: context)
        }
        dismiss()
    }
}
