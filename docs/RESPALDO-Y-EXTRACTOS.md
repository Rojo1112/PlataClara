# Respaldo automático e importación de extractos

## Respaldo automático en carpeta

Los datos de una app se borran al desinstalarla. Para evitarlo, PlataClara puede guardar una copia **fuera de la app**:

1. Ajustes › **Respaldo automático** › **Elegir carpeta…**. Escoge una carpeta de Archivos (en el iPhone o en iCloud Drive).
2. La app guarda ahí `PlataClara-AAAA-MM-DD.json` al cerrarse y después de cada registro automático. Conserva los 7 más recientes.
3. Nunca escribe un respaldo vacío, así que una app recién instalada no pisa tu respaldo bueno.

**Después de desinstalar y reinstalar:** Ajustes › Respaldo automático › Elegir carpeta… (la misma) › **Restaurar el último respaldo de la carpeta**.

Limitaciones:
- La sincronización automática con iCloud (CloudKit) exige una cuenta Apple Developer de pago; por eso se usa una carpeta que tú eliges.
- Si la carpeta está en iCloud Drive y el archivo aún no se descargó en el teléfono, ábrelo una vez en la app Archivos antes de restaurar.

El respaldo manual (Ajustes › Respaldo) sigue disponible y usa el mismo formato JSON.

## Importar extractos bancarios

Ajustes › **Importar extracto bancario**:

1. Elige la cuenta a la que pertenece el extracto.
2. Elige el archivo: PDF descargado del banco (con texto), CSV o TXT. Si el PDF tiene contraseña, la app la pide.
3. Revisa la lista: cada renglón que empieza con una fecha se interpreta como un movimiento. Los que ya tenías registrados (mismo monto y cuenta, ±1 día) aparecen **desmarcados**.
4. Pulsa **Importar**. Los movimientos quedan confirmados y cuentan en saldos y estadísticas.

Cómo se interpreta cada renglón:
- Fechas `dd/MM/aaaa`, `dd-MM-aaaa`, `aaaa-MM-dd`, `dd/MM` o con el mes en texto (`01 sep`). Sin año, se usa el del período del extracto o el año actual.
- Un movimiento puede estar en **una sola línea** o repartido en **renglones separados** (fecha, descripción y monto), como en los extractos de Nu.
- El primer monto con separador de miles, `$`, signo o paréntesis es el valor; el segundo, el saldo.
- Negativo, `(…)`, `DB` o ausencia de palabra de ingreso → gasto. `+`, `CR` o palabras como *abono*, *consignación*, *nómina*, *intereses* → ingreso.

Limitaciones:
- Los PDF escaneados como imagen se leen por OCR, que puede equivocarse en algún monto: revisa antes de importar.
- Cada banco formatea distinto; si tu extracto no se interpreta bien, abre un issue con unas líneas de ejemplo **con los datos personales tachados**.

## PDF con contraseña o protegidos

- **Contraseña para abrir** (la mayoría de los bancos; en Nu suele ser tu cédula): la app la pide y desbloquea el PDF.
- **Permisos que bloquean copiar el texto, o PDF escaneados como imagen:** si no se encuentra ningún movimiento en el texto, la app dibuja cada página y la lee con reconocimiento de texto (OCR) en el propio iPhone. También puedes forzarlo con **«Releer como imagen (OCR)»**. Con OCR conviene revisar los montos.
- **Compáralo con el resumen:** antes de importar, la app suma lo seleccionado (entradas, salidas y pagos a tarjeta). Debe coincidir con «lo que entró» y «lo que salió» del extracto.
- **Pago a tu tarjeta** (por ejemplo «Pagaste tu tarjeta» en Nu) se importa como transferencia a tu tarjeta de crédito del mismo banco, no como gasto.
- En Android los PDF aún no se leen (el sistema no abre PDF con contraseña): usa CSV/TXT, o importa desde el iPhone y pasa los datos con el respaldo JSON.
