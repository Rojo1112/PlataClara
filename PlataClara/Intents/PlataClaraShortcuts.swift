import AppIntents

/// Estos atajos aparecen automáticamente en la app Atajos, en Siri y en Spotlight; no hay que crearlos a mano.
struct PlataClaraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
