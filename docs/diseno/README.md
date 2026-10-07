# Diseño de PlataClara

Maqueta de la app para iPhone, con modo claro y oscuro automático.

## Qué hay aquí
- `logo/`: el ícono en tres versiones (predeterminado, modo oscuro y tintado), como SVG de 1024 px **sin esquinas redondeadas**: iOS las aplica solo.
- `pantallas/`: los fuentes de la maqueta (`.dc.html`) y su `canvas.json`.
  - `Portada`: lo que se ve al abrir la app.
  - `Logo`: el ícono y su versión horizontal.
  - `Main`: Inicio · `Estadisticas` · `Importar` · `Aviso` (notificación de cada pago).

Los `.dc.html` están pensados para abrirse en un editor de lienzo de diseño, no como páginas sueltas.

## Decisiones de estilo
- **Marca:** una P hecha con una moneda (asta y aro con un punto al centro). Una sola forma, sin degradados.
- **Color:** acento verde azulado `#0E7C66` para lo bueno y lo principal; naranja `#B45309` (claro) o `#F0A04B` (oscuro) para lo que pide atención. No se usa rojo: gastar más de lo que entró no es una deuda.
- **Tipografía:** Manrope; en la app real se usa la fuente del sistema de iOS.
- **Modo oscuro:** fondo `#0B1513`, tarjetas `#14211E`; los textos de acento pasan a `#5FD8B7`.

## Estado
Es un diseño. La app todavía **no** aplica esta apariencia; se lleva al código por partes: ícono y portada, después modo oscuro y pantallas.
