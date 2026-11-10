import SwiftUI
import SwiftData
import PlataCore

/// Cifrado de los respaldos con una contraseña: activarlo, cambiarla o quitarlo.
struct BackupEncryptionSection: View {
    @Environment(\.modelContext) private var context
    @AppStorage(BackupService.encryptionKey) private var enabled = false
    @State private var hasKey = false
    @State private var password = ""
    @State private var repeated = ""
    @State private var working = false
    @State private var confirmDisable = false
    @State private var message: String?

    private var passwordProblem: String? {
        if password.count < BackupCrypto.minimumPasswordLength { return "Mínimo \(BackupCrypto.minimumPasswordLength) caracteres." }
        if password != repeated { return "Las dos contraseñas no coinciden." }
        return nil
    }

    var body: some View {
        Section {
            LabeledContent("Respaldos", value: enabled ? (hasKey ? "Cifrados" : "Detenidos") : "Sin cifrar")
                .onAppear { hasKey = BackupKeychain.load() != nil }
            if enabled && !hasKey {
                Text("Este iPhone no tiene la llave del cifrado, así que no se están guardando respaldos. Vuelve a poner la contraseña.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            SecureField(enabled ? "Contraseña nueva" : "Contraseña", text: $password)
                .textContentType(.newPassword)
            SecureField("Repítela", text: $repeated)
                .textContentType(.newPassword)
            Button(enabled ? "Cambiar la contraseña" : "Cifrar los respaldos", action: enable)
                .disabled(passwordProblem != nil || working)
                .alert("Cifrado de respaldos", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(message ?? "")
                }
            if enabled {
                Button("Quitar el cifrado", role: .destructive) { confirmDisable = true }
                    .confirmationDialog("Los próximos respaldos se guardarán sin cifrar. ¿Quitar el cifrado?",
                                        isPresented: $confirmDisable, titleVisibility: .visible) {
                        Button("Quitar el cifrado", role: .destructive, action: disable)
                        Button("Cancelar", role: .cancel) {}
                    }
            }
        } header: {
            Text("Cifrar respaldos")
        } footer: {
            Text("Con contraseña, los respaldos de la carpeta y los que compartas solo se pueden abrir con ella. La app guarda una llave en este iPhone para respaldar sola; la contraseña no se guarda. Si la olvidas, esos respaldos no se pueden recuperar: nadie más puede abrirlos. Los respaldos sin cifrar que ya estaban en la carpeta siguen ahí hasta que los borres. La versión de Android todavía no lee respaldos cifrados.")
        }
    }

    private func enable() {
        guard passwordProblem == nil else { return }
        working = true
        defer { working = false }
        do {
            guard try BackupService.enableEncryption(password: password) else {
                message = "El iPhone no dejó guardar la llave del cifrado. No se cambió nada."
                return
            }
            hasKey = true
            password = ""
            repeated = ""
            let saved = BackupFolderService.autoBackup(context: context)
            message = "Listo: los respaldos quedan cifrados. Guarda la contraseña en un lugar seguro: sin ella no se pueden abrir."
                + (saved ? " Ya guardé un respaldo cifrado en la carpeta." : "")
        } catch {
            message = "No se pudo activar el cifrado. No se cambió nada."
        }
    }

    /// Quitar el cifrado exige identificarse: así nadie más lo apaga con el teléfono desbloqueado.
    private func disable() {
        Task {
            guard await AppLock.authenticate(reason: "Quitar el cifrado de los respaldos") else { return }
            BackupService.disableEncryption()
            hasKey = false
            message = "Cifrado quitado. Los próximos respaldos se guardan sin cifrar."
        }
    }
}
