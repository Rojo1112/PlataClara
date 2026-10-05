import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PlataCore

struct BackupFolderSection: View {
    @Environment(\.modelContext) private var context
    @State private var hasFolder = false
    @State private var last: Date?
    @State private var choosing = false
    @State private var confirmRestore = false
    @State private var message: String?

    var body: some View {
        Section {
            LabeledContent("Carpeta", value: hasFolder ? "Elegida" : "Sin elegir")
                .onAppear(perform: refresh)
            if let last {
                LabeledContent("Último respaldo", value: Fecha.diaHora(last))
            }
            Button(hasFolder ? "Cambiar carpeta…" : "Elegir carpeta…") { choosing = true }
                .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
                    switch result {
                    case .success(let url): chooseFolder(url)
                    case .failure: message = "No se pudo abrir la carpeta."
                    }
                }
                .alert("Respaldo automático", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(message ?? "")
                }
            if hasFolder {
                Button("Respaldar ahora") {
                    message = BackupFolderService.autoBackup(context: context)
                        ? "Respaldo guardado en la carpeta."
                        : "No se pudo guardar (¿no hay datos todavía o la carpeta ya no está disponible?)."
                    refresh()
                }
                Button("Restaurar el último respaldo de la carpeta", role: .destructive) { confirmRestore = true }
                    .confirmationDialog("¿Reemplazar todos los datos por el último respaldo de la carpeta?",
                                        isPresented: $confirmRestore, titleVisibility: .visible) {
                        Button("Reemplazar", role: .destructive) { restore() }
                        Button("Cancelar", role: .cancel) {}
                    }
            }
        } header: {
            Text("Respaldo automático")
        } footer: {
            Text("Elige una carpeta de Archivos (en el iPhone o en iCloud Drive). La app guarda ahí una copia cada vez que la cierras y después de cada registro automático, y conserva las 7 últimas. Si desinstalas PlataClara, vuelve a elegir la misma carpeta y restaura.")
        }
    }

    private func refresh() {
        hasFolder = BackupFolderService.hasFolder
        last = BackupFolderService.lastBackup
    }

    private func chooseFolder(_ url: URL) {
        do {
            try BackupFolderService.setFolder(url)
            let existing = BackupFolderService.latestBackupName()
            let saved = BackupFolderService.autoBackup(context: context)
            if existing != nil && !saved {
                message = "Carpeta elegida. Encontré respaldos anteriores: toca «Restaurar el último respaldo de la carpeta» para recuperar tus datos."
            } else {
                message = "Carpeta elegida. El respaldo se guardará automáticamente."
            }
        } catch {
            message = "No se pudo usar esa carpeta: \(error.localizedDescription)"
        }
        refresh()
    }

    private func restore() {
        do {
            let count = try BackupFolderService.restoreLatest(context: context)
            RecurringService.refresh(context: context)
            message = "Respaldo restaurado: \(count) movimientos."
        } catch BackupError.unsupportedVersion(let version) {
            message = "El respaldo usa un formato no compatible (versión \(version)). No se cambió nada."
        } catch {
            message = error.localizedDescription
        }
    }
}
