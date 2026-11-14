import Foundation

/// Un trozo de texto reconocido en una imagen, con su posición. Las medidas van de 0 a 1 sobre el ancho y el alto
/// de la imagen; `midY` se mide desde arriba.
public struct OCRPiece: Equatable, Sendable {
    public let minX: Double
    public let maxX: Double
    public let midY: Double
    public let text: String

    public init(minX: Double, maxX: Double, midY: Double, text: String) {
        self.minX = minX
        self.maxX = maxX
        self.midY = midY
        self.text = text
    }
}

/// Arma líneas de texto a partir de los trozos que entrega el reconocimiento de texto.
public enum OCRLayout {
    /// Dos trozos están en la misma fila si sus centros difieren menos que esto (fracción del alto).
    public static let rowTolerance = 0.008
    /// En la lista de movimientos del banco, el ícono de cada fila ocupa la columna izquierda hasta aquí
    /// (fracción del ancho). El texto de la fila empieza después.
    public static let iconColumnMaxX = 0.19
    /// Arriba de esto está la barra de estado del teléfono (la hora de la captura): ahí no hay íconos de fila.
    public static let statusBarMaxY = 0.06

    /// Une los trozos que están a la misma altura en una línea, de izquierda a derecha, y las líneas de arriba abajo.
    /// - Parameter dropIconColumn: en capturas de la lista de movimientos, descarta lo que el reconocimiento «lee»
    ///   en los íconos: trozos que caben enteros en la columna del ícono y tienen dos letras o menos («·3», «S»,
    ///   «Ez»). Un encabezado de día como «Hoy» tiene tres letras y se conserva.
    public static func lines(from pieces: [OCRPiece], dropIconColumn: Bool = false) -> String {
        let kept = dropIconColumn ? pieces.filter { !isIconNoise($0) } : pieces
        var rows: [[OCRPiece]] = []
        for piece in kept.sorted(by: { $0.midY < $1.midY }) {
            if let last = rows.last, abs(last[0].midY - piece.midY) < rowTolerance {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }
        return rows
            .map { row in row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    static func isIconNoise(_ piece: OCRPiece) -> Bool {
        piece.midY > statusBarMaxY && piece.maxX < iconColumnMaxX && piece.text.filter(\.isLetter).count <= 2
    }
}
