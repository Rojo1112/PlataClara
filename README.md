# PlataClara

App de finanzas personales para iPhone, hecha para Colombia (Nu, Dale!, Ualá, Lulo Bank y cualquier otro banco).

- Registra pagos con **tarjeta de crédito y débito, QR, llaves Bre-B, transferencias e ingresos**.
- **Registro automático** con Atajos de iOS: pagos con Apple Pay, correos del banco y capturas de pantalla de comprobantes.
- **Gastos fijos** del mes (arriendo, servicios, suscripciones) con recordatorio y estado pendiente/pagado.
- **Saldos** por cuenta, **deuda** de tarjetas, **ahorro** del mes y **ahorro posible** (descontando los fijos que faltan).
- Estadísticas por categoría, por método de pago y de los últimos 6 meses.
- **Importa extractos bancarios** (PDF con texto, CSV o TXT): elige la cuenta, revisa los movimientos encontrados y los que ya tenías aparecen desmarcados. Ver [docs/RESPALDO-Y-EXTRACTOS.md](docs/RESPALDO-Y-EXTRACTOS.md).
- **Respaldo automático en una carpeta** de Archivos o iCloud Drive: si desinstalas la app, tus datos siguen ahí y se restauran con un toque.
- **Siempre puedes registrar a mano**: botón **+** en Inicio y Movimientos; lo que la app no entienda queda en «Por revisar».
- **Privada**: todo vive en tu iPhone. Sin servidor, sin cuenta, sin analítica. Respaldo en JSON cuando quieras.

## Descargar e instalar

Ninguna de las dos versiones está en una tienda de apps.

- **iPhone:** descarga `PlataClara.ipa` desde [Releases](https://github.com/Rojo1112/PlataClara/releases/latest) y sigue [docs/INSTALACION.md](docs/INSTALACION.md).
- **Android:** descarga `PlataClara.apk` desde [Releases](https://github.com/Rojo1112/PlataClara/releases?q=android) y sigue [docs/INSTALACION-ANDROID.md](docs/INSTALACION-ANDROID.md). En Android el registro puede ser **automático leyendo las notificaciones de tus apps de banco**, con tu permiso. *(Versión sin probar aún en teléfono real.)*

Ambas versiones guardan sus datos en el mismo formato de respaldo (JSON), así que puedes pasar tus datos de una a otra.

## Registro automático

iOS no permite que ninguna app lea las notificaciones de otras apps. PlataClara usa las vías que sí existen; la guía está en [docs/ATAJOS.md](docs/ATAJOS.md).

## ¿Tu banco no se reconoce bien?

Mira [docs/AGREGAR-BANCO.md](docs/AGREGAR-BANCO.md).

## Desarrollo

- `PlataCore/`: lógica y pruebas (`swift test --package-path PlataCore`).
- `PlataClara/`: app SwiftUI + SwiftData. El proyecto se genera con `xcodegen generate`.
- GitHub Actions corre las pruebas, compila sin firmar y publica el `.ipa` al crear una etiqueta `v*`.

Licencia MIT.
