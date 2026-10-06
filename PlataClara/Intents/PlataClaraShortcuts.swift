import AppIntents

/// Estos atajos aparecen automáticamente en la app Atajos, en Siri y en Spotlight; no hay que crearlos a mano.
/// iOS permite como máximo 10 en total.
struct PlataClaraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CardPaymentIntent(),
                    phrases: ["Registrar pago con tarjeta en \(.applicationName)", "Pagué con tarjeta en \(.applicationName)"],
                    shortTitle: "Pago con tarjeta", systemImageName: "creditcard")
        AppShortcut(intent: QRPaymentIntent(),
                    phrases: ["Registrar pago con QR en \(.applicationName)", "Pagué con QR en \(.applicationName)"],
                    shortTitle: "Pago con QR", systemImageName: "qrcode")
        AppShortcut(intent: SendMoneyIntent(),
                    phrases: ["Registrar envío en \(.applicationName)", "Envié plata en \(.applicationName)"],
                    shortTitle: "Envío a otra cuenta", systemImageName: "arrow.up.right.circle")
        AppShortcut(intent: ReceiveMoneyIntent(),
                    phrases: ["Registrar entrada en \(.applicationName)", "Me llegó plata en \(.applicationName)"],
                    shortTitle: "Entrada de otra cuenta", systemImageName: "arrow.down.left.circle")
        AppShortcut(intent: QuickExpenseIntent(),
                    phrases: ["Registrar gasto en \(.applicationName)", "Anotar un gasto en \(.applicationName)"],
                    shortTitle: "Registrar gasto", systemImageName: "minus.circle")
        AppShortcut(intent: QuickIncomeIntent(),
                    phrases: ["Registrar ingreso en \(.applicationName)", "Anotar un ingreso en \(.applicationName)"],
                    shortTitle: "Registrar ingreso", systemImageName: "plus.circle")
        AppShortcut(intent: MonthSummaryIntent(),
                    phrases: ["¿Cuánto me sobra en \(.applicationName)?", "Resumen del mes en \(.applicationName)"],
                    shortTitle: "Cuánto me sobra", systemImageName: "chart.pie")
        AppShortcut(intent: NewMovementIntent(),
                    phrases: ["Nuevo movimiento en \(.applicationName)", "Abrir formulario en \(.applicationName)"],
                    shortTitle: "Nuevo movimiento", systemImageName: "square.and.pencil")
        AppShortcut(intent: RegisterFromTextIntent(),
                    phrases: ["Registrar aviso en \(.applicationName)"],
                    shortTitle: "Registrar aviso", systemImageName: "text.viewfinder")
        AppShortcut(intent: BackupNowIntent(),
                    phrases: ["Respaldar \(.applicationName)", "Guardar copia de \(.applicationName)"],
                    shortTitle: "Respaldar ahora", systemImageName: "externaldrive")
    }
}
