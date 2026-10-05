# Mejorar el reconocimiento de un banco

PlataClara reconoce avisos con un lector general (`PlataCore/Sources/PlataCore/Parsing/`). Para afinar un banco:

1. Abre un issue con 2 o 3 textos reales de avisos (correo o captura). **Tacha** nombres, números de cuenta completos y saldos: deja solo el formato, por ejemplo `Compraste $XX.XXX en COMERCIO con tu tarjeta terminada en 0000`.
2. Las pistas para identificar el banco están en `BankDetector.rules` (una línea por banco).
3. Las palabras que definen el tipo y el método están en `MovementClassifier`.
4. Agrega una prueba en `PlataCore/Tests/PlataCoreTests/GenericParserTests.swift` con el ejemplo tachado y el resultado esperado, y abre un pull request.
