import Foundation

/// Reglas de nombres y rotación del respaldo automático en carpeta.
public enum BackupRotation {
    public static func fileName(for date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "PlataClara-%04d-%02d-%02d.json", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func isBackupFile(_ name: String) -> Bool {
        name.range(of: #"^PlataClara-\d{4}-\d{2}-\d{2}\.json$"#, options: .regularExpression) != nil
    }

    /// Archivos de respaldo a borrar para conservar solo los `keep` más recientes.
    public static func filesToDelete(names: [String], keep: Int) -> [String] {
        let sorted = names.filter(isBackupFile).sorted(by: >)
        return sorted.count > keep ? Array(sorted.dropFirst(keep)) : []
    }

    public static func latest(names: [String]) -> String? {
        names.filter(isBackupFile).max()
    }

    /// Nunca se escribe un respaldo vacío: una app recién reinstalada no debe pisar el respaldo bueno.
    public static func shouldWrite(accounts: Int, movements: Int) -> Bool {
        accounts > 0 || movements > 0
    }
}
