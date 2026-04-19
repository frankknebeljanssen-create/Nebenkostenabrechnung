//
//  Basis.swift
//  NebenkostenApp — Calc-Layer
//
//  Gemeinsame Typealiases, Rundungs-Utility und Stammdaten-Kontext.
//  Einziger erlaubter Import: Foundation.
//

import Foundation

// MARK: - Typealiases

/// Geldbeträge in Euro. `Decimal` statt `Double`, um Rundungsfehler bei
/// Cent-Beträgen auszuschließen (rechtliche Nachvollziehbarkeit).
typealias Euro = Decimal

/// Flächen in m². Decimal zur Vermeidung von Float-Ungenauigkeit bei
/// Summen über mehrere Einheiten.
typealias Flaeche = Decimal

/// Verbrauchsmengen (Wärme in kWh, Wasser in m³, etc.).
typealias Verbrauch = Decimal

// MARK: - Rundung

/// Unterstützte Rundungsverfahren für Beträge.
///
/// `kaufmaennisch` = "Half away from zero" (5,5 → 6; −5,5 → −6). Das ist
/// das in deutschen Steuer- und Abrechnungskontexten übliche Verfahren.
enum Rundungsmodus {
    case kaufmaennisch
    case abrunden
    case aufrunden
}

extension Decimal {
    /// Rundet auf `stellen` Nachkommastellen mit dem gewählten Modus.
    ///
    /// Default-Modus ist kaufmännisch, weil das in der Praxis fast immer
    /// das gewünschte Verfahren ist.
    func gerundet(auf stellen: Int, modus: Rundungsmodus = .kaufmaennisch) -> Decimal {
        var quelle = self
        var ziel = Decimal()
        let nsModus: NSDecimalNumber.RoundingMode = switch modus {
        case .kaufmaennisch: .plain
        case .abrunden:      .down
        case .aufrunden:     .up
        }
        NSDecimalRound(&ziel, &quelle, stellen, nsModus)
        return ziel
    }
}

// MARK: - Abrechnungskontext

/// Stammdaten-Schnappschuss, den alle Rechner der Calc-Layer brauchen.
///
/// Pur-Value-Type. Die Service-Layer baut diese Struktur aus den
/// @Model-Klassen zusammen und reicht sie nach `Calc/` hinein.
struct AbrechnungsKontext: Equatable, Sendable {
    /// Gesamtwohn-/Nutzfläche der Liegenschaft in m².
    let gesamtflaecheM2: Flaeche

    /// Anzahl aller Wohneinheiten (inkl. Gewerbe und Leerstand).
    let anzahlEinheiten: Int

    /// Start der Abrechnungsperiode (inklusive).
    let periodeVon: Date

    /// Ende der Abrechnungsperiode (inklusive).
    let periodeBis: Date
}
