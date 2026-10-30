# Historial de cambios (iPhone)

Cada versión dice qué cambió y qué está **comprobado**. Hay dos niveles de comprobación:

- ✅ **Probado en un iPhone** con datos reales (extracto y capturas de Nu).
- 🧪 **Probado solo por la compilación automática** (las pruebas de `PlataCore` y que la app compile). Falta confirmarlo en un teléfono.

La versión recomendada para volver atrás si algo falla es la [v0.5.1](https://github.com/Rojo1112/PlataClara/releases/tag/v0.5.1).

---

## Sin publicar — Saldos que parten del banco
**Qué cambió**
- **Saldo de la cuenta:** el campo «Saldo actual» ahora sí es el de hoy. En una cuenta nueva se guarda también como punto de cuadre con la hora de ahora, así que los movimientos anteriores que importes después no lo cambian. En una cuenta existente el campo muestra el saldo que calcula la app; si lo cambias, queda como punto de cuadre, sin tocar el saldo inicial. Antes se guardaba como saldo inicial y la app le restaba otra vez todo lo importado.
- **Importar capturas:** si entre las capturas está la pantalla de inicio de la cuenta («Saldo disponible»), la app lee el saldo y el de las cajitas y ofrece guardarlos como punto de cuadre, con la hora del reloj de la captura (se puede ajustar).
- **Movimientos con la fecha cortada:** si una captura corta la fecha de la última fila y la siguiente no la repite, la app ya no la descarta: la muestra aparte, sin marcar, con la fecha de la fila de arriba, y pregunta si la agregas (ajustando la fecha) o la descartas.

**Comprobado**: 🧪 pruebas de `PlataCore` (120) y las 43 capturas de Nu leídas con OCR en Linux: detecta los 2 movimientos de fecha cortada (−$10.000 y +$30.000) y, con el saldo de la captura de inicio como punto de cuadre, Ahorro Nu da $63.335 y Cajitas $0 aunque el saldo inicial esté mal. Las pantallas no se han compilado aquí (falta Xcode) ni probado en iPhone.

## v0.7.2 — Cajitas como ahorro y capturas más confiables
**Qué cambió**
- **Cajitas:** «Agregaste dinero a tu Cajita» y «Retiraste dinero de tu Cajita» se importan como **traslado** entre la cuenta y sus cajitas, no como gasto ni ingreso. Ya no inflan «Te entró» ni «Te salió» ni aparecen como fuente de ingresos o mayor gasto. Lo que se gasta con plata sacada de una cajita sí cuenta como gasto.
- Estadísticas: sección **Ahorro en cajitas** con cuánto guardaste, cuánto sacaste y si crecieron o usaste de lo ahorrado.
- Capturas: un movimiento **partido entre dos capturas** (monto abajo en una, fecha arriba en la siguiente) ya no se pierde.
- Capturas: **dos movimientos iguales en el mismo minuto** (por ejemplo dos reembolsos de $4.300) ya no se toman por repetidos.
- Capturas: los centavos se redondean (un retiro de $0,87 cuenta como $1) y se entiende la fecha cuando el OCR lee «0ct».

**Comprobado**: 🧪 pruebas de `PlataCore` (117) y una prueba con 43 capturas reales de Nu de octubre leídas con OCR en Linux: 297 de 302 movimientos bien (los 5 restantes no los pudo leer el OCR: montos en gris o fechas cortadas), y Estadísticas da «Te entró» igual al real. La app compila en GitHub; falta probarla en iPhone. Los movimientos de cajita importados antes de esta versión siguen como ingreso o gasto.

## v0.7.1 — Capturas sin tope
**Qué cambió**
- Al importar capturas de pantalla ya no hay tope de 10: se eligen todas las que quieras de una vez.
- Mientras las lee muestra el avance («Leyendo captura 3 de 25…»). Se leen una a la vez para no llenar la memoria.

**Comprobado**: 🧪 compila y pasa las pruebas. Falta probar en iPhone con más de 10 capturas.

## v0.7.0 — Cuadre automático con el banco
**Qué cambió**
- El saldo de cada cuenta parte del **último saldo que dio el banco** (punto de cuadre) y suma solo los movimientos posteriores. Sin puntos de cuadre funciona como antes.
- **Puntos de cuadre** desde el extracto PDF (saldo inicial y final), desde una **captura de la pantalla de inicio** del banco (se lee el saldo en el iPhone) o a mano, con fecha y hora.
- Al importar un extracto: revisa que **inicio + entró − salió + rendimientos − 4x1000** dé el saldo final, avisa lo que no aparece en la lista y ofrece registrarlo como traslado de una cajita. Los rendimientos, el 4x1000 y los costos del resumen se pueden importar como movimientos.
- Pantalla de **cuadre de cada cuenta** (toca la cuenta en Inicio): diferencias entre cuadres, saldo que se vuelve negativo, tramos sin movimientos y combinaciones de retenciones, movimientos repetidos o por revisar que explican la diferencia exacta. Ningún arreglo se aplica sin confirmar.
- **Nivel de confianza** del saldo en Inicio: verificado, alta, media o baja, con la fecha del último cuadre y lo que falta explicar.
- **Cajitas** como parte de la cuenta Nu, con el desglose en Inicio.
- Estadísticas: **¿De dónde viene tu plata?** (ingresos por persona u origen) y el ahorro **contando la plata de terceros**.
- «Cuadrar con el banco» en la cuenta ya no cambia el saldo inicial: guarda un punto de cuadre.
- El respaldo guarda los puntos de cuadre; los respaldos anteriores se siguen leyendo.

**Comprobado**: 🧪 pruebas del cuadre con datos de ejemplo. Falta probar en iPhone, sobre todo el lector de la captura de inicio, que se ajustó sin una captura real.

## v0.6.0 — Nueva marca: ícono, color y portada
**Qué cambió**
- **Ícono nuevo:** una P hecha con una moneda, en tres versiones que iOS elige solo: predeterminado (verde), modo oscuro y tintado.
- **Color de la marca** (verde azulado) en toda la app, con un tono más claro en modo oscuro.
- **Portada** al abrir la app: el logo, el nombre y «Tu plata, clara.», sobre el fondo del modo en que esté el teléfono.
- El logo también aparece en la primera pantalla del tutorial.
- Modo claro y oscuro automático: la app sigue el del teléfono.
- Diseño completo de la maqueta en `docs/diseno/`.

**Comprobado**: 🧪 compila. El ícono, la portada y los colores hay que verlos en un iPhone. En iPhone con iOS 17 solo se usa el ícono predeterminado; el oscuro y el tintado se ven desde iOS 18.

## v0.5.4 — Retenciones, plata de terceros y cuadre con el banco
**Qué cambió**
- Etiquetas **«Retención pendiente»** (el reloj de Nu) y **«Plata de un tercero»**, desde el menú ⋯ al importar o al editar un movimiento. La plata de un tercero cuenta en el saldo, pero no en gastos ni en ingresos.
- El aviso de «gastaste más de lo que entró» ahora es **naranja** y aclara que no es una deuda.
- Estadísticas: sección **«Tu plata hoy»** con el saldo de tus cuentas y lo que queda tras los gastos fijos.
- En cada cuenta: **«Cuadrar con el banco»** escribe el saldo real y ajusta el saldo inicial, sin tocar movimientos.

**Comprobado**: 🧪 pruebas de estadísticas y etiquetas (91 pruebas en total). Falta probar en iPhone.

## v0.5.3 — El PDF se relee solo si no cuadra
**Qué cambió**
- Si la primera lectura del PDF no coincide con los totales que dice el propio PDF, la app lo relee como imagen (OCR) automáticamente y se queda con la lectura que más se acerque.

**Comprobado**: 🧪 compila y pasa las pruebas. Falta confirmar con el extracto real que ya no hace falta tocar «Releer como imagen».

## v0.5.2 — Sin Siri
**Qué cambió**
- La app ya no menciona Siri; los atajos muestran qué pide cada uno (monto, comercio, cuenta).

**Comprobado**: 🧪 compila.

## v0.5.1 — Avisos de cada pago y guía de Apple Pay ⭐ versión estable de referencia
**Qué cambió**
- Cada pago registrado solo (Apple Pay y atajos) llega como **notificación con el monto** y cuánto te sobra este mes.
- Ajustes › **Activar Apple Pay automático**: guía de 6 pasos, estado que se pone verde con el primer pago, y revisión de que el nombre de la tarjeta coincida con Wallet.
- Invitación en Inicio mientras no llegue el primer pago de Apple Pay.

**Comprobado**: 🧪 compila y pasa las pruebas. **Apple Pay automático no se ha confirmado todavía en un iPhone.** iOS no permite que una app cree la automatización «Transacción» por la persona: se crea una sola vez a mano, siguiendo la guía.

## v0.5.0 — Menús, plantillas y tutorial
**Qué cambió**
- Atajos por tipo de pago: tarjeta, QR, envío a otra cuenta y entrada de otra cuenta (más gasto, ingreso, «¿cuánto me sobra?» y respaldar).
- Cuentas: plantillas (Nu, Dale!, Ualá, Lulo, efectivo) y menús desplegables para banco, tipo y días de corte y pago.
- Importar: menú ⋯ en cada movimiento (importar o ignorar, tipo, categoría) y menú «Qué seleccionar».
- Tutorial de primera vez con botón **«Omitir tutorial»**.

**Comprobado**: 🧪 compila. Falta probarlo en iPhone.

## v0.4.0 — Duplicados que no fallan
**Qué cambió**
- Cada renglón del extracto o de una captura se empareja con **un solo** movimiento ya registrado (el más cercano en hora). Subir la misma captura dos veces no duplica nada, y dos compras iguales el mismo día no se confunden.
- Lo que ya estaba registrado se completa con los datos del banco en lugar de descartarse.

**Comprobado**: 🧪 pruebas de emparejamiento. Falta probarlo en iPhone.

## v0.3.1 / v0.3.0 — Estadísticas claras
**Qué cambió**
- Estadísticas con **«Te entró» y «Te salió»** como los muestra el banco, avisos de si gastaste más de lo que entró, pagos a tarjeta, categorías automáticas, mayores gastos y lista de gastos del mes.
- Los reembolsos (por ejemplo de Uber) restan del gasto.

**Comprobado**: ✅ la pantalla de Estadísticas y sus cifras se vieron en un iPhone. 🧪 Las cuentas con las 7 capturas de Nu están en las pruebas automáticas.

## v0.2.6 — Capturas de pantalla
**Qué cambió**
- Importar movimientos desde **capturas** de la lista de la app de Nu (hasta 10), sin repetir filas cortadas ni capturas solapadas.

**Comprobado**: ✅ en un iPhone leyó 38 de 38 movimientos de 7 capturas. Las retenciones con reloj y los cobros tachados no se distinguen en el texto: se desmarcan a mano.

## v0.2.2 — Lectura del extracto en PDF
**Qué cambió**
- El PDF de Nu se lee completo (185 movimientos), fechas siempre gregorianas y comparación contra los totales del propio PDF.

**Comprobado**: ✅ en un iPhone las entradas y salidas coincidieron con el PDF.

---

## Límites conocidos
- **Apple Pay** solo se registra solo al acercar el iPhone al datáfono, y solo si se creó la automatización una vez. Los pagos por internet, QR y envíos no disparan nada: se registran con atajos, a mano o desde capturas.
- **Capturas**: el formato está probado con la app de Nu. Dale!, Ualá y Lulo necesitan ejemplos.
- **Android** no incluye aún lo de las versiones 0.2.2 en adelante (duplicados, avisos, estadísticas nuevas).
