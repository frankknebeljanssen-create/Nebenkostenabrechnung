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
}
