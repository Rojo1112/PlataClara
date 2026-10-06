import Foundation
import SwiftData
import UserNotifications
import PlataCore

/// Avisa en el momento, con una notificación del teléfono, cuánto fue cada pago que se registró solo
/// (Apple Pay, atajos, avisos). También guarda cuándo llegó el último pago por Apple Pay, para saber
/// si la automatización de Atajos está funcionando.
enum PaymentNotifier {
    static let lastApplePayKey = "ultimoApplePayTs"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    static func notify(_ outcome: CaptureOutcome, source: CaptureSource, context: ModelContext) {
        // Que llegue un pago por Apple Pay, aunque ya estuviera registrado, prueba que la automatización funciona.
        if source == .applePay {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastApplePayKey)
        }
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch outcome {
        case .registered(let m):
            content.title = "\(m.kind == .ingreso ? "Entró" : "Pagaste") \(Money.format(m.amount))"
            content.body = [m.merchant, monthLine(context)].compactMap { $0 }.joined(separator: " · ")
        case .review(let m):
            content.title = m.amount > 0 ? "Revisa este movimiento de \(Money.format(m.amount))" : "No entendí un aviso"
            content.body = "Quedó en «Por revisar»."
        case .duplicate:
            return
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    /// «Este mes te sobran $X» o «Este mes salió $Y más de lo que entró».
    @MainActor
    static func monthLine(_ context: ModelContext) -> String {
        let accounts = context.all(Account.self)
        let snapshots = context.all(Movement.self).map { $0.snapshot(categoryName: nil) }
        let savings = Set(accounts.filter { $0.kind != .credito }.map(\.id))
        let s = Stats.summary(movements: snapshots, in: Stats.monthInterval(containing: .now, calendar: .gregoriano),
                              pendingFixed: 0, ownSavingsAccounts: savings)
        return s.overspent
            ? "Este mes salió \(Money.format(s.deficit)) más de lo que entró"
            : "Este mes te sobran \(Money.format(s.saved))"
    }
}

extension PaymentNotifier {
    /// Aviso de ejemplo para ver cómo llegan, sin registrar ningún movimiento.
    @MainActor
    static func sendTest(context: ModelContext) {
        let content = UNMutableNotificationContent()
        content.title = "Pagaste $ 25.000"
        content.body = "TIENDA DE EJEMPLO · \(monthLine(context))"
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: UUID().uuidString, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }
}
