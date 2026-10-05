import SwiftUI

struct ShortcutsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("iOS no deja que ninguna app lea las notificaciones de otras apps. PlataClara registra tus movimientos con automatizaciones de Atajos: correo del banco, Apple Pay y capturas de pantalla.")
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
