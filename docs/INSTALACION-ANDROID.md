# Instalar PlataClara en Android

Requisitos: Android 8 o superior.

> **Estado:** esta versión se compila y se prueba automáticamente en GitHub (pruebas del núcleo), pero **todavía no se ha probado en un teléfono real**. Si algo falla, abre un issue con lo que viste.

## Instalar

1. En el teléfono, abre la [última versión de Android](https://github.com/Rojo1112/PlataClara/releases?q=android) y descarga `PlataClara.apk`.
2. Ábrelo. Android pedirá permiso para **instalar apps desconocidas** al navegador o al administrador de archivos que lo abrió: acéptalo solo para esta instalación.
3. Si Play Protect avisa que la app no es conocida, elige **Instalar de todos modos**. El APK está firmado con una llave de depuración porque no se publica en Google Play.
4. Abre PlataClara y crea tus cuentas en **Ajustes › Cuentas**.

## Registro automático con las notificaciones del banco

Android, a diferencia del iPhone, permite que una app lea notificaciones con tu permiso:

1. Ajustes de PlataClara › **Dar acceso a las notificaciones** › activa PlataClara.
   - Si Android muestra *«Ajuste restringido»* (apps instaladas fuera de Google Play, Android 13+): Ajustes del teléfono › Apps › PlataClara › menú ⋮ › **Permitir ajustes restringidos**, y vuelve a intentar.
2. Espera una notificación de tu banco (Nu, Dale!, Ualá, Lulo Bank…). Su app aparecerá en la lista de Ajustes.
3. **Marca** la app de tu banco y, si quieres, asócialo con su cuenta. Solo se leen las apps marcadas; las demás se ignoran.
4. Para que Android no cierre el servicio: Ajustes del teléfono › Apps › PlataClara › Batería › **Sin restricciones**.

Lo que PlataClara no entienda queda en **Por revisar**, con el texto original. Una notificación promocional con un monto (por ejemplo «te prestamos hasta $5.000.000») también puede llegar ahí; bórrala con un toque.

## Respaldo que sobrevive a desinstalar

Ajustes › **Respaldo automático** › *Elegir carpeta*. La app guarda `PlataClara-AAAA-MM-DD.json` en esa carpeta (en el teléfono o en tu nube) cada vez que la cierras o registra algo, y conserva las 7 últimas. Después de reinstalar: elige la misma carpeta y toca **Restaurar el último respaldo de la carpeta**.

El formato es el mismo de la app del iPhone: puedes llevar tus datos de un sistema a otro con *Exportar* e *Importar*.

## Importar extractos

Ajustes › **Importar extracto bancario**: elige la cuenta y un archivo **CSV o TXT** del banco. Los PDF aún no se leen en Android; descarga el extracto en CSV si tu banco lo ofrece.
