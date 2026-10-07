# Historial de cambios (iPhone)

Cada versión dice qué cambió y qué está **comprobado**. Hay dos niveles de comprobación:

- ✅ **Probado en un iPhone** con datos reales (extracto y capturas de Nu).
- 🧪 **Probado solo por la compilación automática** (las pruebas de `PlataCore` y que la app compile). Falta confirmarlo en un teléfono.

La versión recomendada para volver atrás si algo falla es la [v0.5.1](https://github.com/Rojo1112/PlataClara/releases/tag/v0.5.1).

---

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
