import Foundation

struct WiderspruchOutput {
    let email: EmailOutput
    let whatsapp: WhatsAppOutput
    let pdfDaten: PDFDaten
}

struct EmailOutput {
    let betreff: String
    let brieftext: String   // Voller Brief mit Briefkopf (für PDF)
    let emailBody: String   // Nur Inhalt ohne Briefkopf (für MFMailCompose)
}

struct WhatsAppOutput {
    let nachricht: String   // Max 500 Zeichen
}

struct PDFDaten {
    let absenderName: String
    let absenderAdresse: String
    let empfaengerName: String
    let empfaengerAdresse: String
    let datum: String
    let betreff: String
    let brieftext: String
    let frist: String       // 4 Wochen ab heute
}
