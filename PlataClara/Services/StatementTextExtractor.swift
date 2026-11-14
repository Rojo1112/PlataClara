import Foundation
import PDFKit
import UIKit
import Vision
import PlataCore

/// Saca el texto de un PDF. Primero se usa el texto incrustado; si no hay (PDF escaneado o con la copia
/// de texto bloqueada) se dibuja cada página y se lee la imagen con OCR en el propio teléfono.
enum StatementTextExtractor {
    static func embeddedText(of document: PDFDocument) -> String {
        document.string ?? ""
    }

    static func ocrText(of document: PDFDocument) async -> String {
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let image = render(page) else { continue }
            pages.append(await recognize(image))
        }
        return pages.joined(separator: "\n")
    }

    /// Lee el texto de una captura de pantalla o foto.
    /// - Parameter dropIconColumn: para capturas de la lista de movimientos del banco: descarta lo que el
    ///   reconocimiento «lee» en el ícono de cada fila, que si no queda metido en el nombre.
    static func ocrText(of image: UIImage, dropIconColumn: Bool = false) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await recognize(cgImage, dropIconColumn: dropIconColumn)
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale: CGFloat = 2.5
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.cgImage
    }

    private static func recognize(_ image: CGImage, dropIconColumn: Bool = false) async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["es-ES", "en-US"]
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: lines(from: request.results ?? [], dropIconColumn: dropIconColumn))
            }
        }
    }

    /// Une los trozos que están en la misma fila de la página en una sola línea, de izquierda a derecha.
    /// Vision mide desde abajo; `OCRLayout` desde arriba.
    private static func lines(from observations: [VNRecognizedTextObservation], dropIconColumn: Bool) -> String {
        let pieces: [OCRPiece] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return OCRPiece(minX: box.minX, maxX: box.maxX, midY: 1 - box.midY, text: text)
        }
        return OCRLayout.lines(from: pieces, dropIconColumn: dropIconColumn)
    }
}
