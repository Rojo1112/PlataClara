# Registro automático con Atajos

iOS no deja que ninguna app lea las notificaciones de otras apps. PlataClara registra tus movimientos con automatizaciones de la app Atajos. Lo que no entienda llega a «Por revisar» con el texto original.

## 1. Pagos con Apple Pay

1. Atajos › Automatización › Nueva automatización › **Transacción**.
2. Elige tus tarjetas y marca **Ejecutar inmediatamente**.
3. Acción: **Registrar pago Apple Pay** (PlataClara).
4. Monto = *Cantidad*, Comercio = *Comercio*, Tarjeta = *Tarjeta* (variables de la transacción).
5. En PlataClara › Ajustes › Cuentas, escribe el nombre exacto de cada tarjeta tal como aparece en Wallet.

Solo funciona al acercar el iPhone al datáfono; las compras en línea no disparan esta automatización.

## 2. Correos del banco

1. Agrega tu correo en la app Mail del iPhone.
2. Atajos › Automatización › **Correo** › Remitente: el correo de avisos de tu banco › **Ejecutar inmediatamente**.
3. Acción: **Registrar desde texto**. Texto = *Cuerpo*, Remitente = *Remitente*, Origen = *Correo del banco*.
4. En PlataClara › Ajustes › Cuentas, agrega ese remitente en la cuenta correspondiente.

## 3. Captura de un comprobante (QR, llave, transferencia)

1. Crea un atajo con tres acciones: **Hacer captura de pantalla** › **Extraer texto de la imagen** › **Registrar desde texto** (Origen = *Captura de pantalla*).
2. Asígnalo al toque posterior (Ajustes › Accesibilidad › Tocar › Toque posterior) o al botón de acción.
3. Con el comprobante o la notificación del banco en pantalla, toca dos veces la parte trasera del iPhone.

## 4. Registro manual rápido

Di «Nuevo movimiento en PlataClara», o añade ese atajo al botón de acción o al widget de Atajos en la pantalla de bloqueo.

## Qué no se puede automatizar

Las notificaciones push de los bancos no son legibles por ninguna app en iOS. Si tu banco solo avisa por notificación, usa la captura de pantalla (paso 3) o el registro manual (paso 4).
