import Foundation
#if canImport(CryptoKit) && canImport(CommonCrypto)
import CryptoKit
import CommonCrypto
#endif

/// Sobre de un respaldo cifrado. Sigue siendo un archivo JSON: lo cifrado va en `payload` (AES-256-GCM: nonce,
/// datos y sello juntos) y la llave sale de la contraseña con PBKDF2-SHA256, la sal y las iteraciones del sobre.
public struct EncryptedBackup: Codable, Equatable, Sendable {
    public static let formatName = "plataclara-cifrado"

    public var format: String
    public var version: Int
    public var kdf: String
    public var iterations: Int
    public var salt: Data
    public var payload: Data

    public init(iterations: Int, salt: Data, payload: Data) {
        self.format = Self.formatName
        self.version = 1
        self.kdf = "pbkdf2-sha256"
        self.iterations = iterations
        self.salt = salt
        self.payload = payload
    }
}

/// Llave derivada de la contraseña, con la sal y las iteraciones con que se derivó. Es lo que se guarda en el
/// llavero del teléfono para cifrar los respaldos automáticos sin pedir la contraseña cada vez.
public struct BackupKey: Codable, Equatable, Sendable {
    public let salt: Data
    public let iterations: Int
    public let key: Data

    public init(salt: Data, iterations: Int, key: Data) {
        self.salt = salt
        self.iterations = iterations
        self.key = key
    }
}

public enum BackupCryptoError: Error, Equatable {
    /// La contraseña (o la llave guardada) no abre este respaldo, o el archivo fue alterado.
    case wrongPassword
    /// El sobre usa una versión o una derivación que esta app no conoce.
    case unsupported
    case passwordTooShort
}

public enum BackupCrypto {
    public static let defaultIterations = 600_000
    public static let minimumPasswordLength = 8

    /// El sobre del archivo, si es un respaldo cifrado. Un respaldo normal (sin cifrar) devuelve nil.
    public static func envelope(of data: Data) -> EncryptedBackup? {
        guard let envelope = try? JSONDecoder().decode(EncryptedBackup.self, from: data),
              envelope.format == EncryptedBackup.formatName else { return nil }
        return envelope
    }

    public static func isEncrypted(_ data: Data) -> Bool { envelope(of: data) != nil }

    #if canImport(CryptoKit) && canImport(CommonCrypto)
    /// Deriva la llave de la contraseña. Sin `salt` crea una nueva (al activar el cifrado); con la del sobre, la
    /// misma llave que cifró ese respaldo.
    public static func makeKey(password: String, salt: Data? = nil, iterations: Int = defaultIterations) throws -> BackupKey {
        // La misma contraseña escrita con tildes compuestas o descompuestas debe dar la misma llave.
        let normalized = password.precomposedStringWithCanonicalMapping
        guard normalized.count >= minimumPasswordLength else { throw BackupCryptoError.passwordTooShort }
        let salt = salt ?? Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let passwordBytes = Array(normalized.utf8)
        var key = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBufferPointer { passwordPointer in
            salt.withUnsafeBytes { saltPointer in
                passwordPointer.withMemoryRebound(to: CChar.self) { chars in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), chars.baseAddress, passwordBytes.count,
                                         saltPointer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), &key, key.count)
                }
            }
        }
        guard status == kCCSuccess else { throw BackupCryptoError.unsupported }
        return BackupKey(salt: salt, iterations: iterations, key: Data(key))
    }

    /// Cifra un respaldo y lo devuelve como JSON (el sobre).
    public static func encrypt(_ plain: Data, with key: BackupKey) throws -> Data {
        let sealed = try AES.GCM.seal(plain, using: SymmetricKey(data: key.key))
        guard let combined = sealed.combined else { throw BackupCryptoError.unsupported }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(EncryptedBackup(iterations: key.iterations, salt: key.salt, payload: combined))
    }

    /// Abre un respaldo cifrado con una llave ya derivada (la del llavero).
    public static func decrypt(_ data: Data, with key: BackupKey) throws -> Data {
        guard let envelope = envelope(of: data), envelope.version == 1, envelope.kdf == "pbkdf2-sha256" else {
            throw BackupCryptoError.unsupported
        }
        guard envelope.salt == key.salt, envelope.iterations == key.iterations,
              let box = try? AES.GCM.SealedBox(combined: envelope.payload),
              let plain = try? AES.GCM.open(box, using: SymmetricKey(data: key.key)) else {
            throw BackupCryptoError.wrongPassword
        }
        return plain
    }

    /// Abre un respaldo cifrado con la contraseña. Devuelve también la llave, para seguir cifrando con ella.
    public static func decrypt(_ data: Data, password: String) throws -> (plain: Data, key: BackupKey) {
        guard let envelope = envelope(of: data), envelope.version == 1, envelope.kdf == "pbkdf2-sha256" else {
            throw BackupCryptoError.unsupported
        }
        let key: BackupKey
        do {
            key = try makeKey(password: password, salt: envelope.salt, iterations: envelope.iterations)
        } catch BackupCryptoError.passwordTooShort {
            throw BackupCryptoError.wrongPassword
        }
        return (try decrypt(data, with: key), key)
    }
    #endif
}
