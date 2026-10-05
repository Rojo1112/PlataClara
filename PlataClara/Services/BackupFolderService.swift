import Foundation
import SwiftData
import PlataCore

enum BackupFolderError: LocalizedError {
    case sinCarpeta, sinRespaldos

    var errorDescription: String? {
        switch self {
        case .sinCarpeta: return "Primero elige la carpeta de respaldo."
        case .sinRespaldos: return "La carpeta no tiene respaldos de PlataClara."
        }
    }
}

/// Respaldo automático en una carpeta elegida por el usuario (Archivos o iCloud Drive).
/// Vive fuera de la app, así que sobrevive a desinstalarla.
@MainActor
enum BackupFolderService {
    private static let bookmarkKey = "carpetaRespaldoBookmark"
    private static let lastKey = "ultimoRespaldoAutomatico"
    static let keepCount = 7

    static var hasFolder: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }
    static var lastBackup: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    static func setFolder(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        UserDefaults.standard.set(try url.bookmarkData(), forKey: bookmarkKey)
    }

    private static func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private static func backupNames(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    static func latestBackupName() -> String? {
        guard let folder = resolveFolder() else { return nil }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        return BackupRotation.latest(names: backupNames(in: folder))
    }

    /// Escribe el respaldo del día y conserva los 7 más recientes. Nunca escribe un respaldo vacío.
    @discardableResult
    static func autoBackup(context: ModelContext, now: Date = .now) -> Bool {
        guard let folder = resolveFolder() else { return false }
        guard BackupRotation.shouldWrite(accounts: context.all(Account.self).count,
                                         movements: context.all(Movement.self).count) else { return false }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        do {
            let data = try BackupCodec.encode(BackupService.makeFile(context: context))
            let name = BackupRotation.fileName(for: now, calendar: .gregoriano)
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            for old in BackupRotation.filesToDelete(names: backupNames(in: folder), keep: keepCount) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
            }
            UserDefaults.standard.set(now, forKey: lastKey)
            return true
        } catch {
            return false
        }
    }

    /// Restaura el respaldo más reciente de la carpeta; devuelve cuántos movimientos recuperó.
    static func restoreLatest(context: ModelContext) throws -> Int {
        guard let folder = resolveFolder() else { throw BackupFolderError.sinCarpeta }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        guard let name = BackupRotation.latest(names: backupNames(in: folder)) else { throw BackupFolderError.sinRespaldos }
        return try BackupService.restore(from: folder.appendingPathComponent(name), context: context)
    }
}
