import XCTest
@testable import PlataCore

final class BackupEnvelopeTests: XCTestCase {
    func testUnRespaldoNormalNoEsUnSobre() throws {
        let plain = Data(#"{"version":1,"exportedAt":"2026-10-04T12:00:00Z","accounts":[],"movements":[]}"#.utf8)
        XCTAssertFalse(BackupCrypto.isEncrypted(plain))
        XCTAssertFalse(BackupCrypto.isEncrypted(Data("no es json".utf8)))
    }

    func testElSobreSeReconoceYGuardaSalEIteraciones() throws {
        let envelope = EncryptedBackup(iterations: 1_000, salt: Data([1, 2, 3]), payload: Data([9, 9]))
        let data = try JSONEncoder().encode(envelope)
        XCTAssertTrue(BackupCrypto.isEncrypted(data))
        XCTAssertEqual(BackupCrypto.envelope(of: data), envelope)
        // Otro JSON con campos parecidos pero otro formato no cuenta.
        let other = Data(#"{"format":"otro","version":1,"kdf":"x","iterations":1,"salt":"AQ==","payload":"AQ=="}"#.utf8)
        XCTAssertFalse(BackupCrypto.isEncrypted(other))
    }
}

#if canImport(CryptoKit) && canImport(CommonCrypto)
final class BackupCryptoTests: XCTestCase {
    // Pocas iteraciones para que las pruebas sean rápidas; la app usa `defaultIterations`.
    let fast = 1_000
    let plain = Data(#"{"version":1,"movements":[{"amount":50000,"merchant":"TIENDA DEMO"}]}"#.utf8)

    func testCifrarYAbrirConLaContrasena() throws {
        let key = try BackupCrypto.makeKey(password: "clave de prueba", iterations: fast)
        let sealed = try BackupCrypto.encrypt(plain, with: key)
        XCTAssertTrue(BackupCrypto.isEncrypted(sealed))
        XCTAssertNil(String(data: sealed, encoding: .utf8)?.range(of: "TIENDA DEMO"))  // no queda nada legible
        let opened = try BackupCrypto.decrypt(sealed, password: "clave de prueba")
        XCTAssertEqual(opened.plain, plain)
        XCTAssertEqual(opened.key, key)  // sirve para seguir cifrando tras restaurar en un teléfono nuevo
        XCTAssertEqual(try BackupCrypto.decrypt(sealed, with: key), plain)
    }

    func testContrasenaEquivocadaOArchivoAlteradoNoAbren() throws {
        let key = try BackupCrypto.makeKey(password: "clave de prueba", iterations: fast)
        let sealed = try BackupCrypto.encrypt(plain, with: key)
        XCTAssertThrowsError(try BackupCrypto.decrypt(sealed, password: "otra clave más")) {
            XCTAssertEqual($0 as? BackupCryptoError, .wrongPassword)
        }
        XCTAssertThrowsError(try BackupCrypto.decrypt(sealed, password: "corta")) {
            XCTAssertEqual($0 as? BackupCryptoError, .wrongPassword)
        }
        var envelope = try XCTUnwrap(BackupCrypto.envelope(of: sealed))
        envelope.payload[envelope.payload.count - 1] ^= 0x01
        XCTAssertThrowsError(try BackupCrypto.decrypt(try JSONEncoder().encode(envelope), with: key)) {
            XCTAssertEqual($0 as? BackupCryptoError, .wrongPassword)
        }
        // La llave de otro cifrado (otra sal) tampoco abre.
        let other = try BackupCrypto.makeKey(password: "clave de prueba", iterations: fast)
        XCTAssertNotEqual(other.salt, key.salt)
        XCTAssertThrowsError(try BackupCrypto.decrypt(sealed, with: other))
    }

    func testLaLlaveEsLaDePBKDF2ConocidaYNoDependeDeComoSeEscribanLasTildes() throws {
        // Valor de PBKDF2-HMAC-SHA256 calculado con otra implementación (hashlib de Python), 4096 iteraciones.
        let salt = Data("saltSALTsaltSALTsaltSALTsaltSALTsalt".utf8)
        let key = try BackupCrypto.makeKey(password: "passwordPASSWORDpassword", salt: salt, iterations: 4096)
        XCTAssertEqual(key.key.map { String(format: "%02x", $0) }.joined(),
                       "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1")
        let composed = try BackupCrypto.makeKey(password: "contraseña", salt: salt, iterations: fast)
        let decomposed = try BackupCrypto.makeKey(password: "contrasen\u{0303}a", salt: salt, iterations: fast)
        XCTAssertEqual(composed.key, decomposed.key)
    }

    func testContrasenaCortaNoSeAcepta() {
        XCTAssertThrowsError(try BackupCrypto.makeKey(password: "1234567", iterations: fast)) {
            XCTAssertEqual($0 as? BackupCryptoError, .passwordTooShort)
        }
    }

    func testCadaRespaldoUsaUnNonceDistinto() throws {
        let key = try BackupCrypto.makeKey(password: "clave de prueba", iterations: fast)
        XCTAssertNotEqual(try BackupCrypto.encrypt(plain, with: key), try BackupCrypto.encrypt(plain, with: key))
    }
}
#endif
