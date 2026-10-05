import SwiftUI
import SwiftData
import PlataCore

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringExpense.dayOfMonth) private var recurring: [RecurringExpense]
    @Query private var occurrences: [RecurringOccurrence]
    @State private var creating = false
    @State private var editing: RecurringExpense?
    @State private var paying: RecurringOccurrence?

    private var monthKey: String { RecurringPlanner.monthKey(for: .now, calendar: .current) }
    private var thisMonth: [RecurringOccurrence] {
        occurrences.filter { $0.monthKey == monthKey }.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Pendiente este mes")
                        Spacer()
                        Text(Money.format(RecurringService.pendingTotal(monthKey: monthKey, occurrences: occurrences, recurring: recurring)))
                            .monospacedDigit().fontWeight(.semibold).foregroundStyle(.orange)
                    }
                }
                Section("Este mes") {
                    ForEach(thisMonth) { occurrence in
                        if let item = recurring.first(where: { $0.id == occurrence.recurringID }) {
                            occurrenceRow(occurrence, item: item)
                        }
                    }
                }
                Section("Todos mis fijos") {
                    ForEach(recurring) { item in
                        Button { editing = item } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text("Día \(item.dayOfMonth) · \(item.method.displayName)\(item.active ? "" : " · inactivo")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Money.format(item.amount)).monospacedDigit()
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: deleteRecurring)
                }
            }
            .overlay {
                if recurring.isEmpty {
                    ContentUnavailableView("Sin gastos fijos", systemImage: "calendar",
                                           description: Text("Agrega arriendo, servicios, suscripciones… lo que pagas sí o sí cada mes."))
                }
            }
            .navigationTitle("Gastos fijos")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating, onDismiss: { RecurringService.refresh(context: context) }) { RecurringFormView(item: nil) }
            .sheet(item: $editing, onDismiss: { RecurringService.refresh(context: context) }) { RecurringFormView(item: $0) }
            .sheet(item: $paying) { occurrence in
                let item = recurring.first { $0.id == occurrence.recurringID }
                PayOccurrenceView(occurrence: occurrence, name: item?.name ?? "Fijo", suggestedAmount: item?.amount ?? 0)
            }
        }
    }

    private func occurrenceRow(_ occurrence: RecurringOccurrence, item: RecurringExpense) -> some View {
        HStack {
            Image(systemName: icon(for: occurrence.status)).foregroundStyle(color(for: occurrence.status))
            VStack(alignment: .leading) {
                Text(item.name)
                Text("\(occurrence.status.displayName) · vence el \(occurrence.dueDate.formatted(.dateTime.day().month()))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.format(item.amount)).monospacedDigit()
        }
        .swipeActions(edge: .leading) {
            if occurrence.status == .pendiente {
                Button("Pagado") { paying = occurrence }.tint(.green)
            }
        }
        .swipeActions(edge: .trailing) {
            if occurrence.status == .pendiente {
                Button("Omitir") { RecurringService.skip(occurrence, context: context) }.tint(.orange)
            } else {
                Button("Reabrir") { RecurringService.reopen(occurrence, context: context) }.tint(.blue)
            }
        }
    }

    private func icon(for status: OccurrenceStatus) -> String {
        switch status {
        case .pendiente: return "circle"
        case .pagado: return "checkmark.circle.fill"
        case .omitido: return "minus.circle"
        }
    }

    private func color(for status: OccurrenceStatus) -> Color {
        switch status {
        case .pendiente: return .orange
        case .pagado: return .green
        case .omitido: return .secondary
        }
    }

    private func deleteRecurring(at offsets: IndexSet) {
        for index in offsets {
            let item = recurring[index]
            for occurrence in occurrences where occurrence.recurringID == item.id && occurrence.status == .pendiente {
                context.delete(occurrence)
            }
            context.delete(item)
        }
        try? context.save()
        RecurringService.refresh(context: context)
    }
}
