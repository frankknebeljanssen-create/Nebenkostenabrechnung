//
//  DokumentAblageService.swift
//  NebenkostenApp — Services
//
//  Speichert gescannte/importierte Dokumente im App-Documents-
//  Verzeichnis unter /Scans/ und legt ein GespeichertesDokument-
//  @Model dazu an. Erzeugt parallel ein 300×300-Thumbnail.
//
//  Eingabe immer als `Data` — so kann die Service-API gleichermaßen
//  Kamera-Scans (via VNDocumentCameraViewController), Galerie-Bilder
//  (UIImage → Data) und Datei-Importe (PDF/JPG aus FilePicker)
//  verarbeiten.
//

import Foundation
import SwiftData
import UIKit
import PDFKit

enum DokumentAblageFehler: Error, LocalizedError {
    case documentsOrdnerFehlt
    case schreibenFehlgeschlagen(underlying: Error)
    case thumbnailFehlgeschlagen
    case unbekannterTyp(endung: String)

    var errorDescription: String? {
        switch self {
        case .documentsOrdnerFehlt:
            return "Dokument-Ablage konnte nicht angelegt werden."
        case .schreibenFehlgeschlagen(let u):
            return "Datei konnte nicht gespeichert werden: \(u.localizedDescription)"
        case .thumbnailFehlgeschlagen:
            return "Vorschau konnte nicht erzeugt werden."
        case .unbekannterTyp(let e):
            return "Dateityp .\(e) wird nicht unterstützt."
        }
    }
}

@MainActor
enum DokumentAblageService {

    // MARK: - Konstanten

    /// Unterordner unter ~/Documents/.
    static let scansUnterordner = "Scans"
    /// Thumbnail-Unterordner.
    static let thumbnailUnterordner = "Scans/Thumbnails"
    /// Thumbnail-Kantenlänge in px.
    static let thumbnailPx: CGFloat = 300

    // MARK: - Pfade

    /// Absolute URL des ~/Documents/-Verzeichnisses der App.
    static func documentsURL() throws -> URL {
        let fm = FileManager.default
        guard let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DokumentAblageFehler.documentsOrdnerFehlt
        }
        return url
    }

    /// Absolute URL zu einem relativen Pfad (z.B. "Scans/foo.pdf").
    static func absoluterPfad(fuer relativer: String) throws -> URL {
        try documentsURL().appendingPathComponent(relativer)
    }

    // MARK: - Dateiname

    /// scan-20260420-194530.<endung>
    static func generiereDateiname(endung: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        let ts = f.string(from: Date())
        let zufall = String(Int.random(in: 100...999))
        return "scan-\(ts)-\(zufall).\(endung)"
    }

    // MARK: - Speichern

    /// Speichert `data` unter /Scans/<autoname.ext>, erzeugt ein
    /// Thumbnail, legt das GespeichertesDokument-@Model an und gibt
    /// es zurück. Der Caller muss noch `context.save()` rufen.
    ///
    /// - Parameters:
    ///   - data: Inhalt (PDF oder Bild).
    ///   - endung: Datei-Endung ohne Punkt ("pdf", "jpg", "png", "heic").
    ///   - quelle: Herkunft des Dokuments.
    ///   - seitenAnzahl: Bei PDFs aus der Quelle ermittelt, sonst 1.
    ///   - context: SwiftData-Context, in den das Model eingefügt wird.
    @discardableResult
    static func speichere(
        data: Data,
        endung: String,
        quelle: DokumentQuelle,
        seitenAnzahl: Int = 1,
        context: ModelContext
    ) throws -> GespeichertesDokument {
        try stelleOrdnerSicher()

        let name = generiereDateiname(endung: endung)
        let relativerPfad = "\(scansUnterordner)/\(name)"
        let absolut = try absoluterPfad(fuer: relativerPfad)

        do {
            try data.write(to: absolut, options: .atomic)
        } catch {
            throw DokumentAblageFehler.schreibenFehlgeschlagen(underlying: error)
        }

        let thumbnailRelativ = try erzeugeThumbnail(
            fuerQuelle: data, endung: endung, dateiname: name
        )

        let doc = GespeichertesDokument()
        doc.dateiname = relativerPfad
        doc.thumbnailPfad = thumbnailRelativ
        doc.dateigroesseBytes = data.count
        doc.seitenAnzahl = seitenAnzahl
        doc.quelle = quelle
        context.insert(doc)
        return doc
    }

    /// Löscht Datei + Thumbnail + Model-Eintrag.
    static func loesche(
        _ dokument: GespeichertesDokument,
        context: ModelContext
    ) {
        let fm = FileManager.default
        if let url = try? absoluterPfad(fuer: dokument.dateiname) {
            try? fm.removeItem(at: url)
        }
        if !dokument.thumbnailPfad.isEmpty,
           let url = try? absoluterPfad(fuer: dokument.thumbnailPfad) {
            try? fm.removeItem(at: url)
        }
        context.delete(dokument)
    }

    // MARK: - Multi-Image → PDF

    /// Rendert mehrere UIImages in ein A4-PDF. Jedes Bild wird auf
    /// die A4-Kontextbreite skaliert (proportional, zentriert).
    static func pdfAusBildern(_ bilder: [UIImage]) throws -> Data {
        guard !bilder.isEmpty else {
            throw DokumentAblageFehler.thumbnailFehlgeschlagen
        }
        let a4 = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: a4)
        let data = renderer.pdfData { ctx in
            for bild in bilder {
                ctx.beginPage()
                zeichneBildProportional(bild, in: a4)
            }
        }
        return data
    }

    private static func zeichneBildProportional(_ bild: UIImage, in rect: CGRect) {
        let imageRatio = bild.size.width / bild.size.height
        let targetRatio = rect.width / rect.height
        var zielrect = rect.insetBy(dx: 20, dy: 20)
        if imageRatio > targetRatio {
            let hoehe = zielrect.width / imageRatio
            zielrect = CGRect(
                x: zielrect.minX,
                y: zielrect.midY - hoehe / 2,
                width: zielrect.width,
                height: hoehe
            )
        } else {
            let breite = zielrect.height * imageRatio
            zielrect = CGRect(
                x: zielrect.midX - breite / 2,
                y: zielrect.minY,
                width: breite,
                height: zielrect.height
            )
        }
        bild.draw(in: zielrect)
    }

    // MARK: - Intern

    private static func stelleOrdnerSicher() throws {
        let fm = FileManager.default
        let docs = try documentsURL()
        let scans = docs.appendingPathComponent(scansUnterordner, isDirectory: true)
        let thumbs = docs.appendingPathComponent(thumbnailUnterordner, isDirectory: true)
        for url in [scans, thumbs] {
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    /// Erzeugt ein 300×300-JPG-Thumbnail aus Bild- oder PDF-Daten.
    private static func erzeugeThumbnail(
        fuerQuelle data: Data,
        endung: String,
        dateiname: String
    ) throws -> String {
        let thumbnailName = (dateiname as NSString).deletingPathExtension + ".jpg"
        let relativ = "\(thumbnailUnterordner)/\(thumbnailName)"
        let absolut = try absoluterPfad(fuer: relativ)

        guard let bild = renderEndungToUIImage(data: data, endung: endung) else {
            throw DokumentAblageFehler.thumbnailFehlgeschlagen
        }
        let thumbnail = skaliere(bild, max: thumbnailPx)
        guard let jpg = thumbnail.jpegData(compressionQuality: 0.75) else {
            throw DokumentAblageFehler.thumbnailFehlgeschlagen
        }
        do {
            try jpg.write(to: absolut, options: .atomic)
        } catch {
            throw DokumentAblageFehler.schreibenFehlgeschlagen(underlying: error)
        }
        return relativ
    }

    private static func renderEndungToUIImage(data: Data, endung: String) -> UIImage? {
        let e = endung.lowercased()
        if e == "pdf" {
            return erstePDFSeiteAlsBild(data)
        }
        if ["jpg", "jpeg", "png", "heic", "heif"].contains(e) {
            return UIImage(data: data)
        }
        return nil
    }

    private static func erstePDFSeiteAlsBild(_ data: Data) -> UIImage? {
        guard let doc = PDFDocument(data: data), let seite = doc.page(at: 0) else {
            return nil
        }
        let bounds = seite.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let bild = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            seite.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return bild
    }

    private static func skaliere(_ bild: UIImage, max seite: CGFloat) -> UIImage {
        let ratio = bild.size.width / bild.size.height
        let ziel: CGSize
        if bild.size.width >= bild.size.height {
            ziel = CGSize(width: seite, height: seite / ratio)
        } else {
            ziel = CGSize(width: seite * ratio, height: seite)
        }
        let renderer = UIGraphicsImageRenderer(size: ziel)
        return renderer.image { _ in
            bild.draw(in: CGRect(origin: .zero, size: ziel))
        }
    }
}
