//
//  ScanServiceTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Integrations-Tests für die Speicher-Pfad-Logik und den
//  Multi-Page-PDF-Flow (Spec-Punkt C6 der Task 1.1).
//

import Foundation
import SwiftData
import UIKit
import PDFKit
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct ScanServiceTests {

    private func dummyBild(_ farbe: UIColor) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            farbe.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func frischerContainer() throws -> ModelContainer {
        try ModelContainer.preview()
    }

    @Test("Jahres-Unterordner: Datei landet unter Scans/<aktuelles Jahr>/")
    func jahresOrdner_pfad() async throws {
        let container = try frischerContainer()
        let ctx = container.mainContext

        let jpg = dummyBild(.red).jpegData(compressionQuality: 0.7)!
        let doc = try DokumentAblageService.speichere(
            data: jpg, endung: "jpg",
            quelle: .mediathek, seitenanzahl: 1,
            context: ctx
        )
        try ctx.save()

        let teile = doc.dateipfadRelativ.split(separator: "/").map(String.init)
        #expect(teile.count == 3)
        #expect(teile[0] == "Scans")
        #expect(teile[1].count == 4)
        #expect(Int(teile[1]) != nil)
    }

    @Test("GespeichertesDokument bekommt Dateiname + Pfad + Größe + Quelle gesetzt")
    func felder_werden_befuellt() async throws {
        let container = try frischerContainer()
        let ctx = container.mainContext

        let jpg = dummyBild(.green).jpegData(compressionQuality: 0.7)!
        let doc = try DokumentAblageService.speichere(
            data: jpg, endung: "jpg",
            quelle: .mediathek, seitenanzahl: 1,
            context: ctx
        )
        try ctx.save()

        #expect(doc.quelle == .mediathek)
        #expect(doc.seitenanzahl == 1)
        #expect(doc.dateigroesseBytes == jpg.count)
        #expect(!doc.dateiname.isEmpty)
        #expect(!doc.dateipfadRelativ.isEmpty)
        #expect(doc.dateipfadRelativ.hasSuffix(doc.dateiname))
        // Default-Dokumenttyp nach Speichern: .sonstiges (wird später
        // in DokumentErfassungView überschrieben).
        #expect(doc.dokumenttyp == .sonstiges)
    }

    @Test("Mehrseitiger Kamera-Scan: PDF hat N Seiten und ist als PDF gespeichert")
    func kameraScan_mehrseitig() async throws {
        let container = try frischerContainer()
        let ctx = container.mainContext

        let bilder = [dummyBild(.red), dummyBild(.blue), dummyBild(.green)]
        let pdfData = try DokumentAblageService.pdfAusBildern(bilder)
        let doc = try DokumentAblageService.speichere(
            data: pdfData, endung: "pdf",
            quelle: .kamera,
            seitenanzahl: bilder.count,
            context: ctx
        )
        try ctx.save()

        #expect(doc.seitenanzahl == 3)
        #expect(doc.dateipfadRelativ.hasSuffix(".pdf"))
        #expect(doc.quelle == .kamera)

        // PDF tatsächlich auf Platte lesbar + Seitenzahl stimmt
        let url = try DokumentAblageService.absoluterPfad(
            fuer: doc.dateipfadRelativ
        )
        let geladen = PDFDocument(url: url)
        #expect(geladen?.pageCount == 3)

        // Cleanup
        DokumentAblageService.loesche(doc, context: ctx)
        try ctx.save()
    }

    @Test("DateinameOverride wird als Dateiname verwendet, Jahres-Ordner bleibt")
    func dateinameOverride_wird_uebernommen() async throws {
        let container = try frischerContainer()
        let ctx = container.mainContext

        // PDF-Daten erzeugen, damit die Thumbnail-Logik eine PDF-
        // erste-Seite rendern kann (der Override diktiert den Namen,
        // nicht den Inhalt).
        let pdfData = try DokumentAblageService.pdfAusBildern([dummyBild(.blue)])
        let over = "2026-04-20_Rechnung_GASAG.pdf"
        let doc = try DokumentAblageService.speichere(
            data: pdfData, endung: "pdf",
            quelle: .datei, seitenanzahl: 1,
            dateinameOverride: over,
            context: ctx
        )
        try ctx.save()

        #expect(doc.dateiname == over)
        #expect(doc.dateipfadRelativ.hasSuffix(over))
        #expect(doc.dateipfadRelativ.hasPrefix("Scans/"))

        DokumentAblageService.loesche(doc, context: ctx)
        try ctx.save()
    }
}
