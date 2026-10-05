import SwiftData

enum SeedData {
    static let defaultCategories: [(name: String, icon: String, color: String, isIncome: Bool)] = [
        ("Mercado", "cart", "#2E7D32", false),
        ("Restaurantes", "fork.knife", "#EF6C00", false),
        ("Transporte", "car", "#1565C0", false),
        ("Servicios", "bolt", "#F9A825", false),
        ("Arriendo", "house", "#6A1B9A", false),
        ("Salud", "cross.case", "#C62828", false),
        ("Ocio", "gamecontroller", "#AD1457", false),
        ("Compras", "bag", "#00838F", false),
        ("Suscripciones", "repeat", "#5D4037", false),
        ("Educación", "book", "#283593", false),
        ("Otros gastos", "ellipsis.circle", "#616161", false),
        ("Salario", "banknote", "#2E7D32", true),
        ("Transferencias recibidas", "arrow.down.circle", "#00695C", true),
        ("Otros ingresos", "plus.circle", "#558B2F", true)
    ]

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        for (index, c) in defaultCategories.enumerated() {
            context.insert(Category(name: c.name, icon: c.icon, colorHex: c.color, isIncome: c.isIncome, sortOrder: index))
        }
        try? context.save()
    }
}
