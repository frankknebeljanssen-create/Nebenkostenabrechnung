import Foundation

/// V1 (Strukturelle Validierung) und V2 (Cross-Check) der Parser-Extraktion.
///
/// V2: Prüft ob der PARSER korrekt extrahiert hat — „Stimmt die Summe der
/// extrahierten Posten mit der extrahierten Gesamtsumme überein?"
/// NICHT zu verwechseln mit Calculator.checkSummen, das prüft ob der
/// VERMIETER korrekt gerechnet hat (Mieteranteil vs. (gesamt × flaeche / objektflaeche)).
struct ValidationService {

    /// V1: Strukturelle Validierung — ist das JSON vollständig und plausibel?
    /// Bricht die Pipeline ab wenn invalid (siehe Korrektur 9).
    static func validateStruktur(abrechnung: Abrechnung) -> (valid: Bool, fehler: [String]) {
        var fehler: [String] = []

        if abrechnung.meta.objekt.gesamtflaecheQm <= 0 {
            fehler.append("Gesamtfläche fehlt oder ist 0")
        }
        if abrechnung.kostenpositionen.isEmpty {
            fehler.append("Keine Kostenpositionen extrahiert")
        }
        for pos in abrechnung.kostenpositionen {
            if pos.gesamtkosten <= 0 {
                fehler.append("Position \(pos.id) '\(pos.bezeichnungOriginal)': Gesamtkosten ≤ 0")
            }
            if pos.mieterAnteil < 0 {
                fehler.append("Position \(pos.id): negativer Mieteranteil")
            }
        }
        if abrechnung.summeAnteile < 0 {
            fehler.append("Summe der Mieteranteile ist negativ")
        }

        return (fehler.isEmpty, fehler)
    }

    /// V2: Cross-Check — stimmen die Summen der Parser-Extraktion?
    /// Bricht die Pipeline NICHT ab. Ergebnis fließt in den TrustScore ein.
    static func validateCrossCheck(abrechnung: Abrechnung) -> (valid: Bool, fehler: [String]) {
        var fehler: [String] = []

        let berechnete = abrechnung.kostenpositionen.reduce(Decimal(0)) { $0 + $1.mieterAnteil }
        let differenz = abs(berechnete - abrechnung.summeAnteile)
        if differenz > 1 {
            fehler.append("Summe der Einzelposten (\(berechnete)) weicht von Gesamtsumme (\(abrechnung.summeAnteile)) ab")
        }

        for pos in abrechnung.kostenpositionen {
            if pos.mieterAnteil > pos.gesamtkosten {
                fehler.append("Position \(pos.id): Mieteranteil (\(pos.mieterAnteil)) > Gesamtkosten (\(pos.gesamtkosten))")
            }
        }

        return (fehler.isEmpty, fehler)
    }
}
