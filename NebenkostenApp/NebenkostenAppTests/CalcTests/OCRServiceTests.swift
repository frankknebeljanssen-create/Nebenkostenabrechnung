//
//  OCRServiceTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Smoke-Tests für den OCRService. Die Vision-Engine-Ergebnisse
//  variieren je Gerät/Simulator stark; diese Tests prüfen nur die
//  Struktur (Seitenzahl-Trenner, leeres Bild → Confidence 0).
//  Real-World-Qualität wird auf echten iPhones gemessen.
//

import Foundation
import UIKit
import PDFKit
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct OCRServiceTests {

    private func bildMitFarbe(_ farbe: UIColor, _ groesse: CGSize = CGSize(width: 300, height: 300)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: groesse)
        return renderer.image { ctx in
            farbe.setFill()
            ctx.fill(CGRect(origin: .zero, size: groesse))
        }
    }

    @Test("Mehrseitiges PDF liefert konkatenierten Text mit ---SEITE N---Trenner")
    func mehrseitig_seitentrenner() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ocr-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bilder = [bildMitFarbe(.white), bildMitFarbe(.white), bildMitFarbe(.white)]
        let data = try DokumentAblageService.pdfAusBildern(bilder)
        try data.write(to: tmp)

        let ergebnis = try await OCRService.extrahiereText(pdfURL: tmp)
        // Auf weißen Bildern findet Vision vermutlich keinen Text —
        // trotzdem müssen alle Seiten-Markierungen im Volltext stehen.
        #expect(ergebnis.volltext.contains("---SEITE 1---"))
        #expect(ergebnis.volltext.contains("---SEITE 2---"))
        #expect(ergebnis.volltext.contains("---SEITE 3---"))
    }

    @Test("Leeres Bild → leerer Volltext, Confidence 0")
    func leeres_bild_confidence_null() async throws {
        let bild = bildMitFarbe(.white, CGSize(width: 10, height: 10))
        let ergebnis = try await OCRService.extrahiereText(ausBild: bild)
        // Vision kann bei leerem Bild gar nichts finden.
        #expect(ergebnis.volltext.isEmpty || !ergebnis.volltext.contains(where: { $0.isLetter }))
        #expect(ergebnis.confidence == 0.0)
        #expect(ergebnis.niedrigeKonfidenzZeilen.isEmpty)
    }

    @Test("URL nicht vorhanden → dateiNichtGefunden-Fehler")
    func datei_nicht_vorhanden() async throws {
        let url = URL(fileURLWithPath: "/tmp/ocr-nicht-existent-\(UUID().uuidString).pdf")
        do {
            _ = try await OCRService.extrahiereText(pdfURL: url)
            Issue.record("Erwarteter dateiNichtGefunden-Fehler nicht geworfen")
        } catch OCRFehler.dateiNichtGefunden {
            // erwartet
        }
    }
}
