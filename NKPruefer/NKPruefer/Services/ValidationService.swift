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

        // Gesamtfläche ist jetzt optional — fehlend = Warnung, nicht Fehler.
        // Wir können auch ohne Objekt-Gesamtfläche prüfen (z. B. wenn alle
        // Positionen einen Mieteranteil und Verteilerschlüssel haben).
        if let gqm = abrechnung.meta.objekt.gesamtflaecheQm, gqm <= 0 {
            fehler.append("Gesamtfläche ist 0 oder negativ")
        }
        if abrechnung.kostenpositionen.isEmpty {
            fehler.append("Keine Kostenpositionen extrahiert")
        }
        for pos in abrechnung.kostenpositionen {
            // gesamtkosten optional: wenn nil, kein Fehler — kann auf der
            // Abrechnung schlicht fehlen (z. B. nur Mieteranteile angegeben).
            if let gk = pos.gesamtkosten, gk <= 0 {
                fehler.append("Position \(pos.id) '\(pos.bezeichnungOriginal)': Gesamtkosten ≤ 0")
            }
            if pos.mieterAnteil < 0 {
                fehler.append("Position \(pos.id): negativer Mieteranteil")
            }
        }
        if let summe = abrechnung.summeAnteile, summe < 0 {
            fehler.append("Summe der Mieteranteile ist negativ")
        }

        return (fehler.isEmpty, fehler)
    }

    /// V2: Cross-Check — stimmen die Summen der Parser-Extraktion?
    /// Bricht die Pipeline NICHT ab. Ergebnis fließt in den TrustScore ein.
    static func validateCrossCheck(abrechnung: Abrechnung) -> (valid: Bool, fehler: [String]) {
        var fehler: [String] = []

        let berechnete = abrechnung.kostenpositionen.reduce(Decimal(0)) { $0 + $1.mieterAnteil }
        if let summe = abrechnung.summeAnteile {
            let differenz = abs(berechnete - summe)
            if differenz > 1 {
                fehler.append("Summe der Einzelposten (\(berechnete)) weicht von Gesamtsumme (\(summe)) ab")
            }
        }
        // Wenn `summeAnteile` nil ist, können wir den Cross-Check nicht
        // machen — das ist kein Validierungsfehler, sondern fehlende Quelle.

        for pos in abrechnung.kostenpositionen {
            if let gk = pos.gesamtkosten, pos.mieterAnteil > gk {
                fehler.append("Position \(pos.id): Mieteranteil (\(pos.mieterAnteil)) > Gesamtkosten (\(gk))")
            }
        }

        return (fehler.isEmpty, fehler)
    }
}
