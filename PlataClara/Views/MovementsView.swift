import SwiftUI
import SwiftData
import PlataCore

struct MovementsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var accountFilter: UUID?
    @State private var methodFilter: PaymentMethod?
    @State private var categoryFilter: UUID?
    @State private var search = ""
    @State private var creating = false
    @State private var editing: Movement?

    private var visible: [Movement] {
        let categoryNames = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let accountNames = Dictionary(accounts.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return movements.filter { m in
            m.status == .confirmado
                && (accountFilter == nil || m.accountID == accountFilter || m.destinationAccountID == accountFilter)
                && (methodFilter == nil || m.method == methodFilter)
                && (categoryFilter == nil || m.categoryID == categoryFilter)
                && MovementSearch.matches(query: search,
                                          texts: [m.merchant, m.note, m.categoryID.flatMap { categoryNames[$0] },
                                                  m.accountID.flatMap { accountNames[$0] }],
                                          amount: m.amount)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visible) { movement in
                    Button { editing = movement } label: {
                        MovementRow(movement: movement, accounts: accounts, categories: categories)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    let items = offsets.map { visible[$0] }
                    for item in items { MovementStore.delete(item, context: context) }
                }
            }
            .overlay {
                if visible.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "Sin movimientos" : "Sin resultados", systemImage: "list.bullet",
                                           description: Text(search.isEmpty ? "Toca + para registrar uno." : "Ningún movimiento coincide con «\(search)»."))
                }
            }
            .navigationTitle("Movimientos")
            .searchable(text: $search, prompt: "Buscar por nombre o monto")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Cuenta", selection: $accountFilter) {
                            Text("Todas las cuentas").tag(UUID?.none)
                            ForEach(accounts) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                        Picker("Método", selection: $methodFilter) {
                            Text("Todos los métodos").tag(PaymentMethod?.none)
                            ForEach(PaymentMethod.allCases) { Text($0.displayName).tag(PaymentMethod?.some($0)) }
                        }
                        Picker("Categoría", selection: $categoryFilter) {
                            Text("Todas las categorías").tag(UUID?.none)
                            ForEach(categories) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $creating) { MovementFormView(movement: nil) }
            .sheet(item: $editing) { MovementFormView(movement: $0) }
        }
    }
}
