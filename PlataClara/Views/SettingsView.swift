import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PlataCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingRestore: URL?
    /// Respaldo cifrado que espera su contraseña.
    @State private var passwordFor: URL?
    @State private var typedPassword = ""
    @State private var message: String?
    @State private var showTutorial = false
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false

    /// Activar o quitar el bloqueo exige identificarse: así nadie más lo apaga con el teléfono desbloqueado.
    private func setLock(_ on: Bool) {
        guard AppLock.isAvailable else {
            message = "Primero ponle un código de desbloqueo al iPhone (Ajustes › Face ID y código)."
            return
        }
        Task {
            if await AppLock.authenticate(reason: on ? "Activar el bloqueo de PlataClara" : "Quitar el bloqueo de PlataClara") {
                lockEnabled = on
            }
        }
    }

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
                    .alert("Contraseña del respaldo", isPresented: Binding(get: { passwordFor != nil }, set: { if !$0 { passwordFor = nil } })) {
                        SecureField("Contraseña", text: $typedPassword)
                        Button("Restaurar") {
                            if let url = passwordFor { restore(url, password: typedPassword) }
                            typedPassword = ""
                        }
                        Button("Cancelar", role: .cancel) { typedPassword = "" }
                    } message: {
                        Text("Este respaldo está cifrado. Restaurar reemplaza todos los datos actuales.")
                    }
            } header: {
                Text("Respaldo")
            } footer: {
                Text("Guarda el respaldo en Archivos o iCloud Drive. Restaurar reemplaza todos los datos actuales.")
            }
            BackupEncryptionSection()
            Section {
                Toggle("Pedir Face ID o código al abrir", isOn: Binding(get: { lockEnabled }, set: { setLock($0) }))
            } header: {
                Text("Seguridad")
            } footer: {
                Text("Bloquea la app al abrirla y al volver después de un minuto, tapa su contenido en el selector de apps y quita los montos de las notificaciones. Usa Face ID, Touch ID o el código del iPhone. Para proteger también los respaldos, mira «Cifrar respaldos».")
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

    private func restore(_ url: URL, password: String? = nil) {
        do {
            let count = try BackupService.restore(from: url, password: password, context: context)
            RecurringService.refresh(context: context)
            message = "Respaldo restaurado: \(count) movimientos."
        } catch BackupProtectionError.needsPassword {
            passwordFor = url
        } catch let error as BackupProtectionError {
            message = error.localizedDescription
        } catch BackupError.unsupportedVersion(let version) {
            message = "El archivo usa un formato no compatible (versión \(version)). No se cambió nada."
        } catch {
            message = "El archivo no es un respaldo válido. No se cambió nada."
        }
    }
}
