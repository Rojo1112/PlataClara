import SwiftUI
import SwiftData

struct ReviewInboxView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Movement> { $0.statusRaw == "porRevisar" }, sort: \Movement.date, order: .reverse)
    private var items: [Movement]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @State private var editing: Movement?

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { movement in
                    Button { editing = movement } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            MovementRow(movement: movement, accounts: accounts, categories: categories)
                            if let raw = movement.rawText {
                                Text(raw).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    let selected = offsets.map { items[$0] }
                    for movement in selected { MovementStore.delete(movement, context: context) }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("Todo al día", systemImage: "checkmark.circle",
                                           description: Text("Aquí llegan los avisos que la app no pudo registrar sola."))
                }
            }
            .navigationTitle("Por revisar")
            .sheet(item: $editing) { MovementFormView(movement: $0) }
        }
    }
}
