import AppIntents
import PlataCore

enum CaptureOrigin: String, AppEnum {
    case correo, captura

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Origen"
    static var caseDisplayRepresentations: [CaptureOrigin: DisplayRepresentation] = [
        .correo: "Correo del banco",
        .captura: "Captura de pantalla"
    ]

    var source: CaptureSource { self == .correo ? .correo : .captura }
}

struct RegisterFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar desde texto"
    static var description = IntentDescription("Lee el texto de un aviso del banco (correo o captura) y registra el movimiento en PlataClara.")

    @Parameter(title: "Texto") var text: String
    @Parameter(title: "Remitente") var sender: String?
    @Parameter(title: "Origen", default: .correo) var origin: CaptureOrigin

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let outcome = CaptureService.ingestText(text, sender: sender, source: origin.source,
                                                context: Persistence.container.mainContext)
        BackupFolderService.autoBackup(context: Persistence.container.mainContext)
        return .result(value: outcome.message, dialog: IntentDialog(stringLiteral: outcome.message))
    }
}

struct RegisterApplePayIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar pago Apple Pay"
    static var description = IntentDescription("Úsalo en la automatización «Transacción» de Atajos para registrar cada pago con Apple Pay.")

    @Parameter(title: "Monto") var amount: String
    @Parameter(title: "Comercio", default: "") var merchant: String
    @Parameter(title: "Tarjeta", default: "") var card: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let outcome = CaptureService.ingestApplePay(amount: amount, merchant: merchant, card: card,
                                                    context: Persistence.container.mainContext)
        BackupFolderService.autoBackup(context: Persistence.container.mainContext)
        return .result(value: outcome.message, dialog: IntentDialog(stringLiteral: outcome.message))
    }
}

struct NewMovementIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuevo movimiento"
    static var description = IntentDescription("Abre PlataClara en el formulario para registrar un movimiento.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "abrirNuevoMovimiento")
        return .result()
    }
}
