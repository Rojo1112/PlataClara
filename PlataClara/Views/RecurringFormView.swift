import SwiftUI
import SwiftData
import PlataCore

struct RecurringFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    let item: RecurringExpense?

    @State private var name: String
    @State private var amount: Int
    @State private var day: Int
    @State private var accountID: UUID?
    @State private var method: PaymentMethod
    @State private var categoryID: UUID?
    @State private var active: Bool
    @State private var remind: Bool

    init(item: RecurringExpense?) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _amount = State(initialValue: item?.amount ?? 0)
        _day = State(initialValue: item?.dayOfMonth ?? 1)
        _accountID = State(initialValue: item?.accountID)
        _method = State(initialValue: item?.method ?? .debito)
        _categoryID = State(initialValue: item?.categoryID)
        _active = State(initialValue: item?.active ?? true)
        _remind = State(initialValue: item?.remind ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (ej. Arriendo)", text: $name)
                    AmountField(title: "Monto", value: $amount)
                    Stepper("Día del mes: \(day)", value: $day, in: 1...31)
                }
                Section {
                    Picker("Cuenta", selection: $accountID) {
                        Text("Sin definir").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    Picker("Método", selection: $method) {
                        ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Categoría", selection: $categoryID) {
                        Text("Sin categoría").tag(UUID?.none)
                        ForEach(categories.filter { !$0.isIncome }) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                }
                Section {
                    Toggle("Activo", isOn: $active)
                    Toggle("Recordarme el día de pago", isOn: $remind)
                }
            }
            .navigationTitle(item == nil ? "Nuevo fijo" : "Editar fijo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        let target = item ?? RecurringExpense(name: name, amount: amount, dayOfMonth: day)
        if item == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amount = amount
        target.dayOfMonth = day
        target.accountID = accountID
        target.method = method
        target.categoryID = categoryID
        target.active = active
        target.remind = remind
        try? context.save()
        dismiss()
    }
}
