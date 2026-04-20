//
//  DokumentAblageServiceTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Unit-Tests für den Dateiname-Generator, den Multi-Image→PDF-
//  Renderer und den End-to-End-Speichern-Flow (Datei landet auf der
//  Platte, Thumbnail existiert, SwiftData-Model persistiert).
//

import Foundation
import SwiftData
import UIKit
import PDFKit
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct DokumentAblageServiceTests {

    // MARK: - Dateiname

    @Test("Dateiname-Format: scan-YYYYMMDD-HHMMSS-<3 Ziffern>.<endung>")
    func dateiname_format() async throws {
        let name = DokumentAblageService.generiereDateiname(endung: "pdf")
        #expect(name.hasPrefix("scan-"))
        #expect(name.hasSuffix(".pdf"))
        // Struktur prüfen
        let rumpf = name
            .replacingOccurrences(of: "scan-", with: "")
            .replacingOccurrences(of: ".pdf", with: "")
        let teile = rumpf.split(separator: "-").map(String.init)
        #expect(teile.count == 3, "Erwartet 3 Segmente (Datum, Zeit, Zufall)")
        if teile.count == 3 {
            #expect(teile[0].count == 8)   // YYYYMMDD
            #expect(teile[1].count == 6)   // HHMMSS
            #expect(teile[2].count == 3)   // 3-stellige Zufallszahl
        }
    }

    @Test("Dateiname-Generator: zwei Aufrufe liefern unterschiedliche Namen")
    func dateiname_eindeutigkeit() async throws {
        let a = DokumentAblageService.generiereDateiname(endung: "jpg")
        let b = DokumentAblageService.generiereDateiname(endung: "jpg")
        #expect(a != b, "Zwei Namen in derselben Sekunde dürfen sich im Zufalls-Suffix unterscheiden")
    }

    // MARK: - PDF-Konvertierung

    @Test("PDF aus leerem Bildarray wirft thumbnailFehlgeschlagen")
    func pdf_leer_wirft() async throws {
        do {
            _ = try DokumentAblageService.pdfAusBildern([])
            Issue.record("Erwarteter Fehler wurde nicht geworfen.")
        } catch DokumentAblageFehler.thumbnailFehlgeschlagen {
            // erwartet
        }
    }

    @Test("PDF aus 2 Bildern hat 2 Seiten")
    func pdf_mehrere_seiten() async throws {
        let bilder = [dummyBild(.red), dummyBild(.blue)]
        let data = try DokumentAblageService.pdfAusBildern(bilder)
        #expect(!data.isEmpty)
        // Seitenanzahl via PDFKit verifizieren
        let doc = PDFDocument(data: data)
        #expect(doc?.pageCount == 2)
    }

    // MARK: - End-to-End Speichern

    @Test("speichere(): Datei + Thumbnail landen im Documents/Scans, Model ist persistiert")
    func speichern_end_to_end() async throws {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext

        let jpgData = dummyBild(.green).jpegData(compressionQuality: 0.7)!
        let doc = try DokumentAblageService.speichere(
            data: jpgData,
            endung: "jpg",
            quelle: .galerie,
            seitenAnzahl: 1,
            context: ctx
        )
        try ctx.save()

        #expect(doc.quelle == .galerie)
        #expect(doc.seitenAnzahl == 1)
        #expect(doc.dateigroesseBytes == jpgData.count)
        #expect(doc.dateiname.hasPrefix("Scans/scan-"))
        #expect(doc.dateiname.hasSuffix(".jpg"))
        #expect(!doc.thumbnailPfad.isEmpty)

        // Datei existiert
        let fm = FileManager.default
        let dateiUrl = try DokumentAblageService.absoluterPfad(fuer: doc.dateiname)
        let thumbUrl = try DokumentAblageService.absoluterPfad(fuer: doc.thumbnailPfad)
        #expect(fm.fileExists(atPath: dateiUrl.path))
        #expect(fm.fileExists(atPath: thumbUrl.path))

        // SwiftData-Persistenz
        let geladen = try ctx.fetch(FetchDescriptor<GespeichertesDokument>())
        #expect(geladen.count >= 1)

        // Aufräumen
        DokumentAblageService.loesche(doc, context: ctx)
        try ctx.save()
        #expect(!fm.fileExists(atPath: dateiUrl.path))
        #expect(!fm.fileExists(atPath: thumbUrl.path))
    }

    // MARK: - Hilfen

    private func dummyBild(_ farbe: UIColor) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            farbe.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
