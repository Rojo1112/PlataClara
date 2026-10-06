import AppIntents
import SwiftData
import PlataCore

/// Atajos que aparecen solos en la app Atajos, en Siri y en Spotlight apenas se instala PlataClara.
private enum QuickKind {
    @MainActor
    static func register(kind: MovementKind, amount: Int, merchant: String?) -> String {
        guard amount > 0 else { return "El monto debe ser mayor que cero." }
        let context = Persistence.container.mainContext
        let name = merchant?.trimmingCharacters(in: .whitespaces)
        let parsed = ParsedMovement(amount: amount, kind: kind, method: kind == .gasto ? .debito : .transferencia,
                                    merchant: (name?.isEmpty ?? true) ? nil : name, bank: nil, last4: nil, isExplicit: true)
        let outcome = CaptureService.store(parsed: parsed, accountID: nil, rawText: "Atajo · \(kind.displayName) \(amount)",
                                           source: .manual, date: .now, context: context)
        BackupFolderService.autoBackup(context: context)
        return outcome.message
    }
}

struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var description = IntentDescription("Registra un gasto al instante, sin abrir la app.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "Comercio o motivo") var merchant: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = QuickKind.register(kind: .gasto, amount: amount, merchant: merchant)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct QuickIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar ingreso"
    static var description = IntentDescription("Registra plata que te entró, sin abrir la app.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "De quién o por qué") var merchant: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = QuickKind.register(kind: .ingreso, amount: amount, merchant: merchant)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct MonthSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "¿Cuánto me sobra este mes?"
    static var description = IntentDescription("Dice cuánto te entró, cuánto te salió y cuánto te sobra este mes.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = Persistence.container.mainContext
        let calendar = Calendar.gregoriano
        let accounts = context.all(Account.self)
        let snapshots = context.all(Movement.self).map { $0.snapshot(categoryName: nil) }
        let savings = Set(accounts.filter { $0.kind != .credito }.map(\.id))
        let s = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: .now, calendar: calendar),
                              pendingFixed: 0, ownSavingsAccounts: savings)
        let verdict = s.overspent
            ? "Este mes salió \(Money.format(s.deficit)) más de lo que entró."
            : "Este mes te sobran \(Money.format(s.saved))."
        let text = "Te entró \(Money.format(s.totalIn)) y te salió \(Money.format(s.totalOut)). \(verdict)"
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

struct BackupNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Respaldar ahora"
    static var description = IntentDescription("Guarda una copia de tus datos en la carpeta de respaldo que elegiste.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let saved = BackupFolderService.autoBackup(context: Persistence.container.mainContext)
        let text = saved ? "Respaldo guardado en tu carpeta." : "No se pudo respaldar: elige primero una carpeta en Ajustes."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}
