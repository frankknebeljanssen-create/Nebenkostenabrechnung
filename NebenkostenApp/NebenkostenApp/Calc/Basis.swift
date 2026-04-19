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
/// - `kaufmaennisch` = "Half away from zero" (5,5 → 6; −5,5 → −6).
/// - `bankers` = "Half to even" (2,5 → 2; 3,5 → 4). In der Abrechnung
///   als Konvention für finale Positionsbeträge verwendet, weil es
///   Rundungs-Bias über viele Summen minimiert.
enum Rundungsmodus {
    case kaufmaennisch
    case abrunden
    case aufrunden
    case bankers
}

extension Decimal {
    /// Rundet auf `stellen` Nachkommastellen mit dem gewählten Modus.
    ///
    /// Default-Modus ist kaufmännisch. Für finale Positionsbeträge der
    /// Abrechnung (2 Nachkommastellen) wird projektweit `.bankers`
    /// verwendet, intern bleibt Decimal voller Präzision.
    func gerundet(auf stellen: Int, modus: Rundungsmodus = .kaufmaennisch) -> Decimal {
        var quelle = self
        var ziel = Decimal()
        let nsModus: NSDecimalNumber.RoundingMode = switch modus {
        case .kaufmaennisch: .plain
        case .abrunden:      .down
        case .aufrunden:     .up
        case .bankers:       .bankers
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
