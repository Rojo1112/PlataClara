# Cuadre automático con el banco

La app ya no calcula el saldo sumando todos los movimientos desde que creaste la cuenta: basta con que el banco no muestre uno (por ejemplo, plata que salió de una cajita) para que el número quede mal sin avisar. Desde la v0.7.0 el saldo parte de lo que dijo el banco.

## Puntos de cuadre

Un **punto de cuadre** es el saldo que mostró el banco en una fecha y hora. El saldo de la cuenta es **el último punto de cuadre más los movimientos posteriores**. Un movimiento con la misma hora que el punto ya está dentro de él. Sin puntos de cuadre se usa el saldo inicial de la cuenta, como antes.

Salen de tres lugares:
- **El extracto PDF.** Al importarlo, «Tu dinero al inicio del mes» queda como saldo del día anterior al período a las 23:59:59 y «Tu dinero a final del mes» como saldo del último día a las 23:59:59. Si el resumen trae «Dinero en tus cajitas», también se guarda para las cajitas.
- **Una captura de la pantalla de inicio de la app del banco.** En Inicio, toca la cuenta › **Leer el saldo de una captura de inicio**. La app lee el saldo y el de las cajitas en el iPhone; revisa la cifra y la hora antes de guardar.
- **A mano**, en la misma pantalla: el saldo que ves y la hora.

## Qué contrasta la app

1. **Dentro del extracto:** lo leído contra «Lo que entró» y «Lo que salió».
2. **Continuidad del extracto:** inicio + entró − salió + rendimientos − 4x1000 − costos contra el saldo final. Si no da, dice cuánto entró o salió sin aparecer en la lista y ofrece registrarlo como **traslado de una cajita** (no cuenta como ingreso ni como gasto). También compara el saldo inicial con el final del extracto anterior.
3. **Entre un punto de cuadre y el siguiente:** lo que calcula la app contra lo que dice el banco. Si no da, busca la explicación en este orden:
   - **Saldo negativo.** Una cuenta de ahorros no puede quedar en negativo. El primer momento en que el saldo calculado baja de cero marca dónde falta plata que entró, y cuánto como mínimo.
   - **Tramos sin movimientos** al empezar, al terminar o de un día o más en medio: ahí suele estar lo que falta. Sube una captura de ese tramo.
   - **Combinaciones que suman la diferencia exacta** (±1 peso) entre retenciones pendientes que el banco pudo liberar, movimientos registrados dos veces y movimientos por revisar. Prueba todas las combinaciones de los 14 más recientes y propone la más pequeña.
   - Si nada lo explica, la diferencia queda **a la vista**.

Los rendimientos, el 4x1000 y los costos del resumen se agregan a la lista de importación como movimientos del último día del período, para que el saldo cuadre también entre extractos.

**Ningún arreglo se aplica solo:** cada propuesta se confirma con un toque.

## Nivel de confianza

En Inicio, debajo de cada cuenta:
- **Verificado:** el banco dio el saldo hoy y no hay movimientos después.
- **Alta:** el último tramo cuadró con el banco.
- **Media:** todavía no la has cuadrado, o hay una diferencia entre los dos últimos cuadres (con o sin propuesta). El saldo de hoy parte del banco, pero faltan movimientos en ese tramo.
- **Baja:** el saldo calculado queda en negativo después del último cuadre: falta plata que entró.

## Cajitas

Las cajitas de Nu son una cuenta interna ligada a la cuenta Nu. En Inicio se suman a la cuenta, con el desglose «en la cuenta» y «en cajitas». Se crean solas la primera vez que guardas su saldo o registras un traslado.

## Respaldo

Los puntos de cuadre y la cuenta de cajitas viajan en el respaldo JSON. Los respaldos anteriores a la v0.7.0 se siguen leyendo.
