import SwiftUI
import SwiftData

struct PayOccurrenceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let occurrence: RecurringOccurrence
    let name: String
    @State private var amount: Int

    init(occurrence: RecurringOccurrence, name: String, suggestedAmount: Int) {
        self.occurrence = occurrence
        self.name = name
        _amount = State(initialValue: suggestedAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Monto pagado", value: $amount)
                } footer: {
                    Text("Si este mes el valor cambió (por ejemplo, servicios), corrígelo aquí.")
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Marcar pagado") {
                        RecurringService.markPaid(occurrence, amount: amount, context: context)
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
