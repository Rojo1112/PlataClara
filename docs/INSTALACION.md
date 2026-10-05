# Instalar PlataClara en tu iPhone

Requisitos: iPhone con iOS 17 o superior, un PC con Windows o Mac, cable USB y un Apple ID (mejor uno secundario).

## Con iloader (Windows)

1. Descarga `PlataClara.ipa` desde la [última versión](https://github.com/Rojo1112/PlataClara/releases/latest).
2. Instala [iloader](https://github.com/nab138/iloader) y ábrelo. Si no detecta el iPhone, instala «Dispositivos Apple» desde la Microsoft Store y verifica que el servicio «Apple Mobile Device Service» esté iniciado.
3. Conecta el iPhone, desbloquéalo y toca **Confiar**.
4. En iloader inicia sesión con tu Apple ID, elige el iPhone y pulsa **Import IPA** › `PlataClara.ipa`.
5. En el iPhone: **Ajustes › General › VPN y gestión de dispositivos** › tu Apple ID › **Confiar**.
6. Si iOS lo pide: **Ajustes › Privacidad y seguridad › Modo desarrollador** › activar y reiniciar.

## Cada 7 días

Con un Apple ID gratuito la firma dura 7 días. Cuando la app deje de abrir, repite el paso 4 con el mismo `.ipa` (o uno más nuevo). **Tus datos se conservan.**

Para no hacerlo a mano, instala **SideStore** desde iloader: renueva la firma sola cuando el iPhone está en Wi-Fi.

## Actualizar

Descarga el `.ipa` nuevo e instálalo encima, igual que en el paso 4. Antes, por precaución, haz un respaldo en **Ajustes › Respaldo**.
