import Foundation
import Security
import PlataCore

/// Guarda en el llavero del iPhone la llave con que se cifran los respaldos. La contraseña no se guarda.
/// Queda disponible con el teléfono bloqueado (después del primer desbloqueo) porque el respaldo automático
/// corre tras cada pago registrado solo, y no sale de este teléfono ni va a sus copias de seguridad.
enum BackupKeychain {
    private static let service = "com.rojo1112.plataclara.respaldo"
    private static let account = "llave"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func load() -> BackupKey? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(BackupKey.self, from: data)
    }

    @discardableResult
    static func save(_ key: BackupKey) -> Bool {
        guard let data = try? JSONEncoder().encode(key) else { return false }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
