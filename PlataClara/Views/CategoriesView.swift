import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var newName = ""
    @State private var newIsIncome = false

    var body: some View {
        List {
            Section("Nueva categoría") {
                TextField("Nombre", text: $newName)
                Toggle("Es de ingreso", isOn: $newIsIncome)
                Button("Agregar", action: add)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Gastos") { rows(categories.filter { !$0.isIncome }) }
            Section("Ingresos") { rows(categories.filter { $0.isIncome }) }
        }
        .navigationTitle("Categorías")
    }

    private func rows(_ items: [Category]) -> some View {
        ForEach(items) { category in
            Label(category.name, systemImage: category.icon)
                .foregroundStyle(Color(hex: category.colorHex))
        }
        .onDelete { offsets in
            for index in offsets { context.delete(items[index]) }
            try? context.save()
        }
    }

    private func add() {
        let order = (categories.map(\.sortOrder).max() ?? 0) + 1
        context.insert(Category(name: newName.trimmingCharacters(in: .whitespaces),
                                icon: newIsIncome ? "plus.circle" : "tag", colorHex: "#607D8B",
                                isIncome: newIsIncome, sortOrder: order))
        try? context.save()
        newName = ""
    }
}
