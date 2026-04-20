//
//  OCRService.swift
//  NebenkostenApp — Services
//
//  Lokaler Text-Extraktor via Apple Vision (`VNRecognizeTextRequest`).
//  Läuft vollständig on-device — keine Daten verlassen das Gerät auf
//  dieser Ebene (Ebene 1 Rohdaten des 3-Ebenen-Datenmodells).
//
//  Mehrseitige PDFs werden Seite für Seite durchlaufen und mit
//  `---SEITE N---`-Trennern konkateniert. Confidence ist der
//  Mittelwert über alle Zeilen; Zeilen mit Confidence < 0,5 werden
//  separat in `niedrigeKonfidenzZeilen` mitgeliefert, damit die UI
//  sie markieren kann.
//

import Foundation
import Vision
import PDFKit
import UIKit

struct OCRErgebnis: Sendable {
    let volltext: String
    let confidence: Double
    let niedrigeKonfidenzZeilen: [String]
}

enum OCRFehler: Error, LocalizedError {
    case dateiNichtGefunden
    case pdfNichtLesbar
    case visionFehler(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .dateiNichtGefunden:
            return "Dokumentdatei nicht gefunden."
        case .pdfNichtLesbar:
            return "PDF konnte nicht geöffnet werden."
        case .visionFehler(let u):
            return "OCR-Fehler: \(u.localizedDescription)"
        }
    }
}

enum OCRService {

    /// Führt OCR für alle Seiten des Dokuments aus. Greift über
    /// `DokumentAblageService.absoluterPfad` auf die persistierte
    /// PDF-Datei zu.
    @MainActor
    static func extrahiereText(
        aus dokument: GespeichertesDokument
    ) async throws -> OCRErgebnis {
        let relPfad = dokument.dateipfadRelativ
        let url = try DokumentAblageService.absoluterPfad(fuer: relPfad)
        return try await extrahiereText(pdfURL: url)
    }

    /// Test-freundlich: OCR direkt aus einer PDF-URL.
    static func extrahiereText(pdfURL url: URL) async throws -> OCRErgebnis {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OCRFehler.dateiNichtGefunden
        }
        guard let pdf = PDFDocument(url: url) else {
            throw OCRFehler.pdfNichtLesbar
        }

        var seitenTexte: [String] = []
        var confidences: [Double] = []
        var niedrig: [String] = []

        for i in 0..<pdf.pageCount {
            guard let seite = pdf.page(at: i) else { continue }
            let bild = renderePDFSeite(seite)
            let teil = try await ocrImBild(bild)
            seitenTexte.append("---SEITE \(i + 1)---\n\(teil.text)")
            confidences.append(teil.confidence)
            niedrig.append(contentsOf: teil.niedrigeKonfidenz)
        }

        let volltext = seitenTexte.joined(separator: "\n\n")
        let avg = confidences.isEmpty ? 0.0
            : confidences.reduce(0, +) / Double(confidences.count)
        return OCRErgebnis(
            volltext: volltext,
            confidence: avg,
            niedrigeKonfidenzZeilen: niedrig
        )
    }

    /// OCR eines Einzel-Bildes (wird aus `extrahiereText` pro Seite
    /// aufgerufen, ist aber auch separat nutzbar für Zählerstand-
    /// Fotos).
    static func extrahiereText(ausBild bild: UIImage) async throws -> OCRErgebnis {
        let teil = try await ocrImBild(bild)
        return OCRErgebnis(
            volltext: teil.text,
            confidence: teil.confidence,
            niedrigeKonfidenzZeilen: teil.niedrigeKonfidenz
        )
    }

    // MARK: - Intern

    private struct SeitenOCR {
        let text: String
        let confidence: Double
        let niedrigeKonfidenz: [String]
    }

    private static func ocrImBild(_ bild: UIImage) async throws -> SeitenOCR {
        guard let cgImage = bild.cgImage else {
            return SeitenOCR(text: "", confidence: 0, niedrigeKonfidenz: [])
        }
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    cont.resume(throwing: OCRFehler.visionFehler(underlying: error))
                    return
                }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: SeitenOCR(text: "", confidence: 0, niedrigeKonfidenz: []))
                    return
                }
                var teile: [String] = []
                var confs: [Double] = []
                var niedrig: [String] = []
                for obs in observations {
                    guard let top = obs.topCandidates(1).first else { continue }
                    teile.append(top.string)
                    confs.append(Double(top.confidence))
                    if top.confidence < 0.5 {
                        niedrig.append(top.string)
                    }
                }
                let avg = confs.isEmpty ? 0.0 : confs.reduce(0, +) / Double(confs.count)
                cont.resume(returning: SeitenOCR(
                    text: teile.joined(separator: "\n"),
                    confidence: avg,
                    niedrigeKonfidenz: niedrig
                ))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: OCRFehler.visionFehler(underlying: error))
            }
        }
    }

    /// PDF-Seite als UIImage bei 2× DPI (bessere OCR-Qualität).
    private static func renderePDFSeite(_ seite: PDFPage) -> UIImage {
        let bounds = seite.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale,
                          height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            seite.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
