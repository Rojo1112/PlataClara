import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PlataCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingRestore: URL?
    @State private var message: String?
    @State private var showTutorial = false

    var body: some View {
        List {
            Section("Datos") {
                NavigationLink("Cuentas") { AccountsView() }
                NavigationLink("Categorías") { CategoriesView() }
                NavigationLink("Importar extracto bancario") { StatementImportView() }
            }
            Section("Registro automático") {
                NavigationLink("Activar Apple Pay automático") { ApplePaySetupView() }
                NavigationLink("Todos los atajos") { ShortcutsGuideView() }
                Button("Ver el tutorial de nuevo") { showTutorial = true }
            }
            BackupFolderSection()
            Section {
                Button("Preparar respaldo") {
                    do { exportURL = try BackupService.exportURL(context: context) }
                    catch { message = "No se pudo crear el respaldo: \(error.localizedDescription)" }
                }
                if let exportURL {
                    ShareLink("Compartir respaldo", item: exportURL)
                }
                Button("Restaurar respaldo…") { importing = true }
            } header: {
                Text("Respaldo")
            } footer: {
                Text("Guarda el respaldo en Archivos o iCloud Drive. Restaurar reemplaza todos los datos actuales.")
            }
            Section("Acerca de") {
                LabeledContent("Versión", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                Link("Código en GitHub", destination: URL(string: "https://github.com/Rojo1112/PlataClara")!)
            }
        }
        .navigationTitle("Ajustes")
        .sheet(isPresented: $showTutorial) { OnboardingView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): pendingRestore = url
            case .failure: message = "No se pudo abrir el archivo."
            }
        }
        .confirmationDialog("¿Reemplazar todos los datos por los del respaldo?",
                            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .visible) {
            Button("Reemplazar", role: .destructive) {
                if let url = pendingRestore { restore(url) }
                pendingRestore = nil
            }
            Button("Cancelar", role: .cancel) { pendingRestore = nil }
        }
        .alert("Respaldo", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func restore(_ url: URL) {
        do {
            let count = try BackupService.restore(from: url, context: context)
            RecurringService.refresh(context: context)
            message = "Respaldo restaurado: \(count) movimientos."
        } catch BackupError.unsupportedVersion(let version) {
            message = "El archivo usa un formato no compatible (versión \(version)). No se cambió nada."
        } catch {
            message = "El archivo no es un respaldo válido. No se cambió nada."
        }
    }
}
