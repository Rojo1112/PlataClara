import AppIntents

struct PlataClaraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NewMovementIntent(),
                    phrases: ["Nuevo movimiento en \(.applicationName)", "Registrar gasto en \(.applicationName)"],
                    shortTitle: "Nuevo movimiento", systemImageName: "plus.circle")
        AppShortcut(intent: RegisterFromTextIntent(),
                    phrases: ["Registrar aviso en \(.applicationName)"],
                    shortTitle: "Registrar aviso", systemImageName: "text.viewfinder")
    }
}
