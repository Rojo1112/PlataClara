import SwiftUI
import SwiftData
import PlataCore

struct MovementFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    let movement: Movement?

    @State private var kind: MovementKind
    @State private var amount: Int
    @State private var method: PaymentMethod
    @State private var accountID: UUID?
    @State private var destinationID: UUID?
    @State private var categoryID: UUID?
    @State private var merchant: String
    @State private var note: String
    @State private var date: Date
    @State private var errors: [MovementValidationError] = []

    init(movement: Movement?) {
        self.movement = movement
        _kind = State(initialValue: movement?.kind ?? .gasto)
        _amount = State(initialValue: movement?.amount ?? 0)
        _method = State(initialValue: movement?.method ?? .debito)
        _accountID = State(initialValue: movement?.accountID)
        _destinationID = State(initialValue: movement?.destinationAccountID)
        _categoryID = State(initialValue: movement?.categoryID)
        _merchant = State(initialValue: movement?.merchant ?? "")
        _note = State(initialValue: movement?.note ?? "")
        _date = State(initialValue: movement?.date ?? .now)
    }

    private var isReview: Bool { movement?.status == .porRevisar }

    var body: some View {
        NavigationStack {
            Form {
                if isReview, let raw = movement?.rawText {
                    Section("Texto recibido") {
                        Text(raw).font(.footnote).textSelection(.enabled)
                    }
                }
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(MovementKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    AmountField(title: "Monto", value: $amount)
                    if kind != .transferencia {
                        Picker("Método", selection: $method) {
                            ForEach(PaymentMethod.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                    Picker(kind == .transferencia ? "Desde" : "Cuenta", selection: $accountID) {
                        Text("Elegir…").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    if kind == .transferencia {
                        Picker("Hacia", selection: $destinationID) {
                            Text("Elegir…").tag(UUID?.none)
                            ForEach(accounts) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                    }
                    DatePicker("Fecha", selection: $date)
                } footer: {
                    if kind == .transferencia {
                        Text("Para pagar una tarjeta de crédito, elige la tarjeta en «Hacia». No cuenta como gasto.")
                    }
                }
                if kind != .transferencia {
                    Section {
                        Picker("Categoría", selection: $categoryID) {
                            Text("Sin categoría").tag(UUID?.none)
                            ForEach(categories.filter { $0.isIncome == (kind == .ingreso) }) {
                                Text($0.name).tag(UUID?.some($0.id))
                            }
                        }
                        TextField(kind == .ingreso ? "De quién" : "Comercio o destinatario", text: $merchant)
                    }
                }
                Section { TextField("Nota", text: $note, axis: .vertical) }
                if !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.self) { Text($0.message).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle(movement == nil ? "Nuevo movimiento" : (isReview ? "Revisar" : "Editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(isReview ? "Confirmar" : "Guardar", action: save) }
            }
            .onAppear {
                if accountID == nil, accounts.count == 1 { accountID = accounts[0].id }
            }
            .onChange(of: accountID) { _, newID in adjustMethod(for: newID) }
        }
    }

    /// Al elegir una tarjeta de crédito el método pasa a «crédito»; al volver a una cuenta de ahorros, a «débito».
    private func adjustMethod(for id: UUID?) {
        guard kind == .gasto, let account = accounts.first(where: { $0.id == id }) else { return }
        if account.kind == .credito {
            method = .credito
        } else if method == .credito {
            method = .debito
        }
    }

    private func save() {
        let finalMethod: PaymentMethod = kind == .transferencia ? .transferencia : method
        let destination = kind == .transferencia ? destinationID : nil
        errors = MovementValidator.validate(amount: amount, kind: kind, accountID: accountID, destinationAccountID: destination)
        guard errors.isEmpty else { return }

        let target = movement ?? Movement(amount: amount, date: date, kind: kind, method: finalMethod,
                                          accountID: accountID, source: .manual, status: .confirmado)
        if movement == nil { context.insert(target) }
        target.amount = amount
        target.date = date
        target.kind = kind
        target.method = finalMethod
        target.accountID = accountID
        target.destinationAccountID = destination
        target.categoryID = kind == .transferencia ? nil : categoryID
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        target.merchant = trimmedMerchant.isEmpty ? nil : trimmedMerchant
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.note = trimmedNote.isEmpty ? nil : trimmedNote
        target.status = .confirmado
        try? context.save()
        MovementStore.didConfirm(target, context: context)
        dismiss()
    }
}
