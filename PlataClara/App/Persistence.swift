import SwiftData

enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([Account.self, Movement.self, Category.self, RecurringExpense.self, RecurringOccurrence.self])
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
    }()
}
