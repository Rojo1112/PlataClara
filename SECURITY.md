# Seguridad

## Reportar una falla

No abras un issue público con los detalles. Usa **Security › Report a vulnerability** en este repositorio (reporte privado de GitHub). Incluye la versión de la app, el sistema y los pasos para reproducirla. Nunca pegues datos reales: tacha nombres, cuentas y saldos.

## Versiones con soporte

Solo la última versión publicada en [Releases](https://github.com/Rojo1112/PlataClara/releases).

## Lo que protege la app y lo que no

- Los datos viven solo en el teléfono y la app no se conecta a internet. Ver [docs/PRIVACIDAD.md](docs/PRIVACIDAD.md).
- En iPhone los datos quedan cifrados por el sistema mientras el teléfono no se haya desbloqueado desde que se encendió. No se usa un nivel más estricto porque el registro automático (Apple Pay, atajos) debe poder escribir con el teléfono bloqueado.
- El bloqueo con Face ID es opcional (Ajustes › Seguridad) y protege la interfaz, no cifra los datos aparte.
- Los respaldos JSON van sin cifrar salvo que actives **Ajustes › Cifrar respaldos** (iPhone): AES-256-GCM con una llave derivada de tu contraseña (PBKDF2-SHA256, 600.000 iteraciones). La llave se guarda en el llavero del iPhone para el respaldo automático; la contraseña no se guarda y no hay forma de recuperar un respaldo si se olvida. Android todavía no cifra ni lee respaldos cifrados.
- El `.ipa` se publica sin firmar y cada persona lo firma con su propio Apple ID. El `.apk` de Android se firma con una llave de depuración: no sirve para comprobar quién lo compiló y puede no instalarse encima de una versión anterior.
