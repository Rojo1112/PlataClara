import Foundation
import PDFKit
import UIKit
import Vision

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
    static func ocrText(of image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await recognize(cgImage)
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

    private static func recognize(_ image: CGImage) async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["es-ES", "en-US"]
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try? handler.perform([request])
                continuation.resume(returning: lines(from: request.results ?? []))
            }
        }
    }

    /// Une los trozos que están en la misma fila de la página en una sola línea, de izquierda a derecha.
    private static func lines(from observations: [VNRecognizedTextObservation]) -> String {
        let items: [(x: CGFloat, y: CGFloat, text: String)] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (observation.boundingBox.minX, observation.boundingBox.midY, text)
        }
        let sorted = items.sorted { $0.y > $1.y }
        var rows: [[(x: CGFloat, y: CGFloat, text: String)]] = []
        for item in sorted {
            if let last = rows.last, abs(last[0].y - item.y) < 0.008 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        return rows
            .map { row in row.sorted { $0.x < $1.x }.map { $0.text }.joined(separator: " ") }
            .joined(separator: "\n")
    }
}
