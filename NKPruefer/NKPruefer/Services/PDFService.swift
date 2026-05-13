import Foundation
import UIKit

struct PDFService {

    static func generate(from daten: PDFDaten) -> Data {
        // A4: 595.2 × 841.8 pt bei 72 dpi
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 56  // ~2 cm

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            let textRect = CGRect(
                x: margin,
                y: margin,
                width: pageRect.width - 2 * margin,
                height: pageRect.height - 2 * margin
            )

            let bodyFont = UIFont.systemFont(ofSize: 11)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)

            var currentY: CGFloat = margin

            // 1. Absender
            let absender = "\(daten.absenderName)\n\(daten.absenderAdresse)"
            currentY = drawText(absender, font: bodyFont, in: textRect, at: currentY)
            currentY += 24

            // 2. Empfänger
            let empfaenger = "\(daten.empfaengerName)\n\(daten.empfaengerAdresse)"
            currentY = drawText(empfaenger, font: bodyFont, in: textRect, at: currentY)
            currentY += 24

            // 3. Datum (rechtsbündig)
            let datumParagraph = NSMutableParagraphStyle()
            datumParagraph.alignment = .right
            let datumAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .paragraphStyle: datumParagraph,
                .foregroundColor: UIColor.black
            ]
            let datumRect = CGRect(x: margin, y: currentY, width: textRect.width, height: 20)
            daten.datum.draw(in: datumRect, withAttributes: datumAttrs)
            currentY += 32

            // 4. Betreff (fett)
            currentY = drawText(daten.betreff, font: headerFont, in: textRect, at: currentY)
            currentY += 16

            // 5. Brieftext
            _ = drawText(daten.brieftext, font: bodyFont, in: textRect, at: currentY)
        }
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        font: UIFont,
        in bounds: CGRect,
        at y: CGFloat
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]

        let attributed = NSAttributedString(string: text, attributes: attrs)
        let drawRect = CGRect(
            x: bounds.origin.x,
            y: y,
            width: bounds.width,
            height: bounds.height - (y - bounds.origin.y)
        )

        attributed.draw(in: drawRect)

        let size = attributed.boundingRect(
            with: CGSize(width: drawRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return y + size.height
    }

    /// Schreibt das PDF in eine temporäre Datei und gibt die URL zurück (z. B. für Share Sheet).
    static func writeTempFile(from daten: PDFDaten, fileName: String) -> URL? {
        let data = generate(from: daten)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Bericht-PDF (v4-19 Fix 5)

    /// Erzeugt eine PDF-Zusammenfassung des Prüfberichts: Eckdaten,
    /// alle Positionen mit Status, Findings, Disclaimer. Geht über
    /// mehrere Seiten wenn nötig (einfaches Seitenumbruch-Handling).
    static func generateBerichtPDF(bericht: Pruefbericht, mietobjekt: Mietobjekt) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 56
        let usableWidth = pageRect.width - 2 * margin
        let pageBottom = pageRect.height - margin

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let h2Font = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let smallFont = UIFont.systemFont(ofSize: 9)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // Hilfsfunktionen
            func zeile(_ s: String, _ font: UIFont, lineSpacing: CGFloat = 3) {
                let para = NSMutableParagraphStyle()
                para.lineSpacing = lineSpacing
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: para,
                    .foregroundColor: UIColor.black
                ]
                let attr = NSAttributedString(string: s, attributes: attrs)
                let h = attr.boundingRect(
                    with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height
                if y + h > pageBottom {
                    ctx.beginPage()
                    y = margin
                }
                attr.draw(in: CGRect(x: margin, y: y, width: usableWidth, height: h))
                y += h
            }

            func abstand(_ d: CGFloat) {
                y += d
                if y > pageBottom { ctx.beginPage(); y = margin }
            }

            // ── 1. Kopf
            zeile("NEBENKOSTEN-PRÜFER", h2Font)
            abstand(2)
            let datumFmt = DateFormatter()
            datumFmt.dateStyle = .long
            datumFmt.locale = Locale(identifier: "de_DE")
            zeile("Prüfbericht vom \(datumFmt.string(from: bericht.pruefDatum))", bodyFont)
            abstand(16)

            // ── 2. Titel
            zeile(bericht.findings.isEmpty ? "Alles korrekt" : "\(bericht.findings.count) Auffälligkeiten gefunden", titleFont)
            abstand(16)

            // ── 3. Eckdaten
            zeile("Eckdaten der Abrechnung", h2Font)
            abstand(4)
            let zr = bericht.abrechnung.meta.zeitraum
            let kurzDate: (Date) -> String = {
                let f = DateFormatter()
                f.dateFormat = "dd.MM.yyyy"
                f.locale = Locale(identifier: "de_DE")
                return f.string(from: $0)
            }
            zeile("Zeitraum:      \(kurzDate(zr.von)) – \(kurzDate(zr.bis))", bodyFont)
            if let obj = bericht.abrechnung.meta.objekt.adresse, !obj.isEmpty {
                zeile("Objekt:        \(obj)", bodyFont)
            } else {
                zeile("Objekt:        \(mietobjekt.adresse)", bodyFont)
            }
            if let bez = bericht.abrechnung.meta.mieterEinheit.bezeichnung, !bez.isEmpty {
                zeile("Wohnung:       \(bez)", bodyFont)
            }
            if let flaeche = bericht.abrechnung.meta.mieterEinheit.flaecheQm {
                zeile("Wohnfläche:    \(formatDecimal(flaeche, fraction: 1)) m²", bodyFont)
            }
            if let vz = bericht.abrechnung.meta.vorauszahlungenGesamt {
                zeile("Vorauszahlung: \(formatEuro(vz))", bodyFont)
            }
            if let ergebnis = bericht.abrechnung.meta.nachzahlungOderGuthaben {
                let typ = bericht.abrechnung.meta.typ
                let label = typ == .guthaben ? "Guthaben" : (typ == .nachzahlung ? "Nachzahlung" : "")
                zeile("Ergebnis:      \(formatEuro(abs(ergebnis))) \(label)".trimmingCharacters(in: .whitespaces), bodyFont)
            }
            abstand(16)

            // ── 4. Geprüfte Positionen
            zeile("Geprüfte Positionen", h2Font)
            abstand(4)
            for pos in bericht.abrechnung.kostenpositionen {
                let finding = bericht.findings.first(where: { $0.positionId == pos.id })
                let statusZeichen: String
                if let f = finding {
                    switch f.schwere {
                    case .fehler: statusZeichen = "[FEHLER]"
                    case .warnung: statusZeichen = "[!]"
                    case .info: statusZeichen = "[i]"
                    }
                } else {
                    statusZeichen = "[OK]"
                }
                let betragStr = formatEuro(pos.mieterAnteil)
                zeile("\(statusZeichen)  \(pos.bezeichnungOriginal) — \(betragStr)", bodyFont)

                if let f = finding {
                    let detail = "    \(f.beschreibung)"
                    zeile(detail, smallFont)
                    if let rg = f.rechtsgrundlage, !rg.isEmpty {
                        zeile("    Grundlage: \(rg)", smallFont)
                    }
                    if let tip = f.handlungsempfehlung, !tip.isEmpty {
                        zeile("    → \(tip)", smallFont)
                    }
                    abstand(4)
                }
            }
            abstand(16)

            // ── 5. Footer
            zeile("Erstellt mit Nebenkosten-Prüfer.", smallFont)
            zeile("Diese Datei ist keine Rechtsberatung im Sinne des RDG.", smallFont)
        }
    }

    /// Schreibt das Bericht-PDF in eine Temp-Datei für den Share-Sheet.
    static func writeBerichtPDF(bericht: Pruefbericht, mietobjekt: Mietobjekt) -> URL? {
        let data = generateBerichtPDF(bericht: bericht, mietobjekt: mietobjekt)
        let dateiSeg = (mietobjekt.bezeichnung ?? mietobjekt.adresse)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .prefix(60)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pruefbericht_\(dateiSeg)")
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Formatter-Helfer

    private static func formatEuro(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "\(wert) €"
    }

    private static func formatDecimal(_ wert: Decimal, fraction: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = fraction
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "\(wert)"
    }
}
