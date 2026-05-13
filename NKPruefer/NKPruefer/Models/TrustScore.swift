import Foundation

struct TrustScore: Codable, Sendable, Hashable {
    /// V1: JSON-Schema vollständig + plausibel
    var strukturValid: Bool = false
    /// V2: Summen der Einzelposten stimmen mit Gesamtsumme
    var crossCheckValid: Bool = false
    /// V3: Validator-Agent bestätigt: steht so im OCR-Text
    var quelltreuValid: Bool = false
    /// V4: Challenger-Agent hat nicht widersprochen
    var debatteBestaetigt: Bool = false
    /// V5: Audit-Agent hat freigegeben
    var auditBestaetigt: Bool = false

    var bestandeneSchichten: Int {
        [strukturValid, crossCheckValid, quelltreuValid,
         debatteBestaetigt, auditBestaetigt]
            .filter { $0 }.count
    }

    var prozent: Int {
        bestandeneSchichten * 20
    }

    var label: String {
        switch prozent {
        case 80...100: return "Verifiziert"
        case 60..<80:  return "Wahrscheinlich"
        case 40..<60:  return "Unsicher"
        default:       return "Nicht verifiziert"
        }
    }
}
