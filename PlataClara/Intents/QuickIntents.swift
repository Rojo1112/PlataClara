import AppIntents
import SwiftData
import PlataCore

/// Atajos que aparecen solos en la app Atajos, en Siri y en Spotlight apenas se instala PlataClara.
/// Pasan por el mismo camino que los avisos y Apple Pay: si después subes una captura o un extracto con el mismo
/// movimiento, no se duplica; se completa con los datos del banco.
enum QuickRegister {
    @MainActor
    static func run(kind: MovementKind, method: PaymentMethod, amount: Int, merchant: String?, accountName: String?) -> String {
        guard amount > 0 else { return "El monto debe ser mayor que cero." }
        let context = Persistence.container.mainContext
        let name = merchant?.trimmingCharacters(in: .whitespaces)
        let account = resolve(accountName, in: context)
        let finalMethod: PaymentMethod = (kind == .gasto && method == .debito && account?.kind == .credito) ? .credito : method
        let parsed = ParsedMovement(amount: amount, kind: kind, method: finalMethod,
                                    merchant: (name?.isEmpty ?? true) ? nil : name, bank: account?.bank, last4: nil, isExplicit: true)
        let outcome = CaptureService.store(parsed: parsed, accountID: account?.id,
                                           rawText: "Atajo · \(kind.displayName) \(amount)", source: .manual,
                                           date: .now, context: context)
        BackupFolderService.autoBackup(context: context)
        return outcome.message
    }

    /// Busca la cuenta por parte de su nombre («nu», «lulo»…). Si no dice cuál o hay duda, queda sin cuenta
    /// y el extracto la completa después.
    @MainActor
    private static func resolve(_ text: String?, in context: ModelContext) -> Account? {
        let wanted = TextNormalizer.fold(text ?? "").trimmingCharacters(in: .whitespaces)
        let accounts = context.all(Account.self)
        guard !wanted.isEmpty else { return accounts.count == 1 ? accounts[0] : nil }
        let found = accounts.filter { TextNormalizer.fold($0.name).contains(wanted) }
        return found.count == 1 ? found[0] : nil
    }
}

struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar gasto"
    static var description = IntentDescription("Registra un gasto al instante, sin abrir la app.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "Comercio o motivo") var merchant: String?
    @Parameter(title: "Cuenta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .gasto, method: .debito, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct QuickIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar ingreso"
    static var description = IntentDescription("Registra plata que te entró, sin abrir la app.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "De quién o por qué") var merchant: String?
    @Parameter(title: "Cuenta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .ingreso, method: .transferencia, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct CardPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pago con tarjeta"
    static var description = IntentDescription("Registra una compra con tarjeta débito o crédito.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "Comercio") var merchant: String?
    @Parameter(title: "Cuenta o tarjeta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .gasto, method: .debito, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct QRPaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pago con QR"
    static var description = IntentDescription("Registra un pago hecho escaneando un código QR.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "Comercio") var merchant: String?
    @Parameter(title: "Cuenta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .gasto, method: .qr, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct SendMoneyIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar envío a otra cuenta"
    static var description = IntentDescription("Registra una plata que enviaste por llave Bre-B o transferencia.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "A quién") var merchant: String?
    @Parameter(title: "Desde qué cuenta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .gasto, method: .llave, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct ReceiveMoneyIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar entrada de otra cuenta"
    static var description = IntentDescription("Registra plata que te llegó de otra cuenta por llave Bre-B o transferencia.")

    @Parameter(title: "Monto (COP)") var amount: Int
    @Parameter(title: "De quién") var merchant: String?
    @Parameter(title: "A qué cuenta") var account: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = QuickRegister.run(kind: .ingreso, method: .llave, amount: amount, merchant: merchant, accountName: account)
        return .result(dialog: IntentDialog(stringLiteral: text))
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
