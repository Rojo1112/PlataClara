import Foundation
import LocalAuthentication

/// Bloqueo de la app con Face ID, Touch ID o el código del iPhone. Es opcional y se activa en Ajustes.
enum AppLock {
    static let enabledKey = "bloqueoActivo"
    /// Volver a la app antes de este tiempo no pide desbloquear (cambiar un momento a la app del banco, por ejemplo).
    static let graceSeconds: TimeInterval = 60

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// El iPhone tiene código (con o sin biometría). Sin código no hay con qué bloquear.
    static var isAvailable: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    /// Pide Face ID o Touch ID y, si fallan, el código del iPhone.
    /// Si al iPhone le quitaron el código, deja pasar: no hay forma de comprobar nada y la app no debe quedar cerrada para siempre.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
