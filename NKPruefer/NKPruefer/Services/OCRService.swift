import Foundation
import UIKit
import Vision

actor OCRService {

    // MARK: - Result Types

    struct OCRResult {
        let fullText: String
        let blocks: [TextBlock]
        let confidence: Double  // 0.0 – 1.0, Durchschnitt aller Blöcke
    }

    struct TextBlock {
        let text: String
        let confidence: Float
        let boundingBox: CGRect  // Normalisierte Vision-Koordinaten (0–1, y=0 unten)
    }

    // MARK: - Public API

    /// Multi-Page-OCR: erkennt Text aus mehreren Seiten und fügt sie
    /// mit `--- Seite N ---`-Markern zusammen. Die Marker helfen den
    /// KI-Agenten in der Pipeline, die Seitenstruktur zu verstehen.
    ///
    /// Konfidenz ist der Durchschnitt aller Seiten (durch Block-Anzahl
    /// gewichtet, damit eine fast leere Seite das Ergebnis nicht
    /// verzerrt). Blocks werden über alle Seiten konkateniert.
    static func recognizeText(from images: [UIImage]) async throws -> OCRResult {
        guard !images.isEmpty else { throw OCRError.noTextFound }
        if images.count == 1 {
            // Fast path — eine Seite, kein Marker nötig.
            return try await recognizeText(from: images[0])
        }

        var stuecke: [String] = []
        var alleBlocks: [TextBlock] = []
        var summe = 0.0
        var blockCount = 0

        for (idx, image) in images.enumerated() {
            do {
                let einzel = try await recognizeText(from: image)
                stuecke.append("--- Seite \(idx + 1) ---")
                stuecke.append(einzel.fullText)
                alleBlocks.append(contentsOf: einzel.blocks)
                let n = einzel.blocks.count
                summe += einzel.confidence * Double(n)
                blockCount += n
            } catch OCRError.noTextFound {
                // Seite ohne erkennbaren Text wird übersprungen, aber
                // im Output trotzdem markiert — der User sieht, dass
                // Seite N leer war.
                stuecke.append("--- Seite \(idx + 1) (kein Text erkannt) ---")
            }
        }

        guard !alleBlocks.isEmpty else { throw OCRError.noTextFound }

        return OCRResult(
            fullText: stuecke.joined(separator: "\n"),
            blocks: alleBlocks,
            confidence: blockCount > 0 ? summe / Double(blockCount) : 0
        )
    }

    static func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["de-DE"]
                    request.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    )
                    try handler.perform([request])

                    guard let observations = request.results, !observations.isEmpty else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    // Vision: y=0 ist unten. Absteigend nach y = von oben nach unten lesen.
                    let sortiert = observations.sorted {
                        $0.boundingBox.origin.y > $1.boundingBox.origin.y
                    }

                    var blocks: [TextBlock] = []
                    for obs in sortiert {
                        guard let kandidat = obs.topCandidates(1).first else { continue }
                        blocks.append(TextBlock(
                            text: kandidat.string,
                            confidence: kandidat.confidence,
                            boundingBox: obs.boundingBox
                        ))
                    }

                    guard !blocks.isEmpty else {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    let fullText = blocks.map(\.text).joined(separator: "\n")
                    let summe = blocks.reduce(0.0) { $0 + Double($1.confidence) }
                    let avgConfidence = summe / Double(blocks.count)

                    continuation.resume(returning: OCRResult(
                        fullText: fullText,
                        blocks: blocks,
                        confidence: avgConfidence
                    ))
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                }
            }
        }
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Das Bild konnte nicht verarbeitet werden."
        case .noTextFound:
            return "Es wurde kein Text im Bild erkannt."
        case .recognitionFailed(let error):
            return "Texterkennung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helpers

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
