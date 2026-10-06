import SwiftUI
import SwiftData
import UserNotifications
import PlataCore

/// Guía de activación del registro automático de Apple Pay. iOS no deja que una app cree la automatización
/// de Atajos por la persona, así que se hace una sola vez con estos pasos y la app verifica que funcione.
struct ApplePaySetupView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @AppStorage(PaymentNotifier.lastApplePayKey) private var lastApplePay: Double = 0
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var notifications: UNAuthorizationStatus = .notDetermined
    @State private var testSent = false

    var body: some View {
        List {
            Section {
                if lastApplePay > 0 {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Funcionando").font(.headline)
                            Text("Último pago por Apple Pay: \(Fecha.diaHora(Date(timeIntervalSince1970: lastApplePay)))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Todavía no llega ningún pago").font(.headline)
                            Text("Cuando pagues con Apple Pay por primera vez, esto se pone en verde.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange) }
                }
            } header: {
                Text("Estado")
            }

            Section {
                switch notifications {
                case .authorized, .provisional, .ephemeral:
                    Label("Avisos permitidos", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button(testSent ? "Aviso enviado: míralo en un segundo" : "Enviarme un aviso de ejemplo") {
                        PaymentNotifier.sendTest(context: context)
                        testSent = true
                    }
                case .denied:
                    Label("Los avisos están bloqueados", systemImage: "bell.slash.fill").foregroundStyle(.orange)
                    Button("Abrir Ajustes del iPhone") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                default:
                    Button("Permitir avisos") {
                        Task {
                            _ = await PaymentNotifier.requestPermission()
                            notifications = await PaymentNotifier.authorizationStatus()
                        }
                    }
                }
            } header: {
                Text("1. Avisos de cuánto pagaste")
            } footer: {
                Text("Cada pago que se registre solo te llega como notificación: «Pagaste $ 25.000 · comercio · este mes te sobran…».")
            }

            Section {
                if accounts.isEmpty {
                    Text("Agrega primero tus cuentas.").foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    let wallet = (account.walletCardName ?? "").trimmingCharacters(in: .whitespaces)
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                            Text(wallet.isEmpty ? "Falta el nombre de la tarjeta en Wallet" : "Wallet: «\(wallet)»")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: wallet.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(wallet.isEmpty ? Color.orange : Color.green)
                    }
                }
                NavigationLink("Editar cuentas") { AccountsView() }
            } header: {
                Text("2. Tus tarjetas")
            } footer: {
                Text("Para que cada pago caiga en la cuenta correcta, el nombre de la tarjeta debe ser igual al que ves en la app Wallet. Si lo dejas vacío, el pago se registra sin cuenta y el extracto lo completa después.")
            }

            Section {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)").font(.caption.bold())
                            .frame(width: 22, height: 22).background(Color.accentColor.opacity(0.2), in: Circle())
                        Text(text).font(.callout)
                    }
                }
                Button("Abrir Atajos") {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                }
            } header: {
                Text("3. Crear la automatización (una sola vez)")
            } footer: {
                Text("iOS no permite que una app cree esta automatización por ti: es una medida de seguridad de Apple. Son unos 30 segundos y queda para siempre. Solo funciona al acercar el iPhone al datáfono, no en compras por internet.")
            }

            Section {
                Text("Haz un pago con Apple Pay. Cuando llegue, el estado de arriba se pone en verde y te llega el aviso.")
            } header: {
                Text("4. Probar")
            }
        }
        .navigationTitle("Apple Pay automático")
        .task { notifications = await PaymentNotifier.authorizationStatus() }
    }

    private static let steps = [
        "En Atajos, toca la pestaña «Automatización» y después «+» arriba.",
        "Elige «Transacción».",
        "Marca tus tarjetas y deja el comercio en «Cualquiera». Toca «Siguiente».",
        "Toca «Añadir acción», busca «PlataClara» y elige «Registrar pago Apple Pay».",
        "En Monto, Comercio y Tarjeta elige las variables de la transacción con esos mismos nombres (o los equivalentes en tu idioma).",
        "Toca «Siguiente», elige «Ejecutar inmediatamente» y apaga «Notificar cuando se ejecute». Toca «Listo».",
    ]
}
