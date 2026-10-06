import SwiftUI
import SwiftData
import AppIntents
import PlataCore

struct ShortcutsGuideView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    var body: some View {
        List {
            Section {
                Text("iOS no deja que ninguna app lea las notificaciones de otras apps. PlataClara registra tus movimientos con automatizaciones de Atajos: correo del banco, Apple Pay y capturas de pantalla.")
            }
            Section {
                ForEach(Self.readyShortcuts, id: \.title) { item in
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: item.icon)
                        }
                        Spacer()
                        Button("Agregar") { openShortcuts() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
            } header: {
                Text("Atajos que ya tienes")
            } footer: {
                Text("Estos atajos ya vienen dentro de la app: aparecen solos en la app Atajos. «Agregar» abre Atajos para que los pongas en el botón de acción, en la pantalla de bloqueo o en la pantalla de inicio. Lo que registren no se duplica si después subes una captura o un extracto: se completa con los datos del banco.")
            }
            Section {
                if accounts.isEmpty {
                    Text("Agrega primero tus cuentas en Ajustes › Cuentas.").foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    let trimmed = (account.walletCardName ?? "").trimmingCharacters(in: .whitespaces)
                    let probe = ApplePayInput.parse(amount: "$1.000,00", merchant: "Prueba", cardName: trimmed, hints: accounts.map(\.hint))
                    let matched = !trimmed.isEmpty && probe?.accountID == account.id
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                            Text(trimmed.isEmpty ? "Falta el nombre de la tarjeta en Wallet" : "Wallet: «\(trimmed)»")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: matched ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(matched ? Color.green : Color.orange)
                    }
                }
            } header: {
                Text("Revisar Apple Pay")
            } footer: {
                Text("Apple Pay solo se registra solo si existe la automatización «Transacción» (paso 1 de abajo) y el nombre de la tarjeta en la cuenta es igual al de Wallet. Aquí ves cuáles cuentas ya están listas, sin registrar nada.")
            }
            Section("1. Pagos con Apple Pay") {
                step("Atajos › Automatización › Nueva automatización › Transacción.")
                step("Elige tus tarjetas y «Ejecutar inmediatamente».")
                step("Acción: «Registrar pago Apple Pay» de PlataClara.")
                step("Monto = Cantidad, Comercio = Comercio, Tarjeta = Tarjeta (variables de la transacción).")
                step("En Ajustes › Cuentas, escribe el nombre exacto de cada tarjeta en Wallet.")
            }
            Section("2. Correos del banco") {
                step("Agrega tu correo en la app Mail del iPhone.")
                step("Atajos › Automatización › Correo › Remitente: el correo de avisos de tu banco › «Ejecutar inmediatamente».")
                step("Acción: «Registrar desde texto». Texto = Cuerpo del correo, Remitente = Remitente, Origen = Correo del banco.")
                step("En Ajustes › Cuentas, agrega ese remitente en la cuenta correspondiente.")
            }
            Section("3. Captura de un comprobante (QR, llave, transferencia)") {
                step("Crea un atajo: «Hacer captura de pantalla» › «Extraer texto de la imagen» › «Registrar desde texto» (Origen = Captura de pantalla).")
                step("Asígnalo al toque posterior (Ajustes › Accesibilidad › Tocar › Toque posterior) o al botón de acción.")
                step("Con el comprobante o la notificación en pantalla, toca dos veces la parte trasera del iPhone.")
            }
            Section("4. Registro manual rápido") {
                step("Di «Nuevo movimiento en PlataClara» o añade ese atajo al botón de acción o a la pantalla de bloqueo.")
            }
            Section {
                Text("Lo que la app no entienda llega a «Por revisar», con el texto original. Nada se pierde.")
            }
        }
        .navigationTitle("Registro automático")
    }

    private func step(_ text: String) -> some View {
        Text(text).font(.callout)
    }
}

private extension ShortcutsGuideView {
    static let readyShortcuts: [(title: String, detail: String, icon: String)] = [
        ("Pago con tarjeta", "Monto, comercio y cuenta", "creditcard"),
        ("Pago con QR", "Monto, comercio y cuenta", "qrcode"),
        ("Envío a otra cuenta", "Monto, a quién y desde qué cuenta", "arrow.up.right.circle"),
        ("Entrada de otra cuenta", "Monto, de quién y a qué cuenta", "arrow.down.left.circle"),
        ("Registrar gasto", "Monto, motivo y cuenta", "minus.circle"),
        ("Registrar ingreso", "Monto, de quién y cuenta", "plus.circle"),
        ("Cuánto me sobra", "Resumen del mes", "chart.pie"),
        ("Nuevo movimiento", "Abre el formulario", "square.and.pencil"),
        ("Registrar aviso", "Lee el texto de un aviso", "text.viewfinder"),
        ("Respaldar ahora", "Guarda una copia de tus datos", "externaldrive"),
    ]

    func openShortcuts() {
        if let url = URL(string: "shortcuts://") { openURL(url) }
    }
}
