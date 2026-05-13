import Foundation
import SwiftData

@Model
final class APIAuditEntry {
    var zeitpunkt: Date
    var agent: String           // "Parser", "Jurist", "Berichterstatter"
    var zweck: String           // "OCR-Extraktion" etc.
    var datenGesendet: String   // Kurz-Zusammenfassung — NIE der volle Text
    var anonymisiert: Bool
    var statsNamen: Int
    var statsIBANs: Int
    var statsEmails: Int
    var statsTelefon: Int

    init(
        agent: String,
        zweck: String,
        datenGesendet: String,
        anonymisiert: Bool,
        statsNamen: Int = 0,
        statsIBANs: Int = 0,
        statsEmails: Int = 0,
        statsTelefon: Int = 0
    ) {
        self.zeitpunkt = Date()
        self.agent = agent
        self.zweck = zweck
        self.datenGesendet = datenGesendet
        self.anonymisiert = anonymisiert
        self.statsNamen = statsNamen
        self.statsIBANs = statsIBANs
        self.statsEmails = statsEmails
        self.statsTelefon = statsTelefon
    }
}
