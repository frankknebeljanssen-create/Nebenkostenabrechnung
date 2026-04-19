//
//  WasserkostenRechner.swift
//  NebenkostenApp — Calc-Layer
//
//  Kombinierte Trinkwasser- + Schmutzwasser-Umlage (BWB). Der effektive
//  €/m³-Preis wird NICHT vom User eingegeben, sondern dynamisch aus
//  BWB-Gesamtkosten und Summe der Einzelverbräuche abgeleitet. So
//  bleibt der Rechner jahresunabhängig und automatisch konsistent, wenn
//  BWB-Preise oder Grundgebühren sich ändern.
//
//  Der Einheit-Verbrauch ist die Summe aus Kaltwasserzähler-Differenz
//  und Warmwasserzähler (WW kommt aus demselben BWB-Hauptzähler).
//  Gartenzwischenzähler werden in Σ mitgerechnet — dadurch trägt der
//  Garten-Nutzer die anteiligen Kosten seines Garten-Wassers. Der
//  rechtliche Abwasser-Abzug (keine Schmutzwasser-Gebühr auf
//  Bewässerung) ist in den BWB-Gesamtkosten bereits berücksichtigt.
//
//  Einziger erlaubter Import: Foundation.
//

import Foundation

struct WasserkostenInput: Equatable, Sendable {
    /// Gesamte BWB-Rechnung brutto (Trinkwasser + Schmutzwasser + alle
    /// Grundgebühren), wie vom Versorger ausgewiesen.
    let bwbGesamtkostenEuro: Euro

    /// Jahres-Verbrauch pro Einheit in m³. Enthält Kaltwasser +
    /// Warmwasser. Für Einheiten mit Garten ist der Gartenanteil im
    /// Verbrauch enthalten.
    let verbrauchProEinheitM3: [String: Verbrauch]

    init(
        bwbGesamtkostenEuro: Euro,
        verbrauchProEinheitM3: [String: Verbrauch]
    ) {
        self.bwbGesamtkostenEuro = bwbGesamtkostenEuro
        self.verbrauchProEinheitM3 = verbrauchProEinheitM3
    }
}

struct WasserkostenErgebnisEinheit: Equatable, Sendable {
    let einheitID: String
    let verbrauchM3: Verbrauch
    let anteilEuro: Euro
}

struct WasserkostenErgebnis: Equatable, Sendable {
    let bwbGesamtkostenEuro: Euro
    /// Σ aller Einzelverbräuche in m³.
    let summeEinzelverbrauchM3: Verbrauch
    /// Dynamisch abgeleiteter Wasserpreis €/m³ = gesamt / Σ.
    let kombiPreisEuroProM3: Euro
    let proEinheit: [WasserkostenErgebnisEinheit]
}

enum WasserkostenRechner {

    /// Berechnet den Wasserkostenanteil pro Einheit über den dynamisch
    /// abgeleiteten Kombi-Preis:
    ///   preis = bwbGesamt / Σ Einheit-Verbrauch
    ///   anteil = verbrauch · preis
    /// Bei Σ = 0 werden alle Einheit-Anteile 0 € (keine Division-by-
    /// Zero-Panik).
    static func berechne(_ input: WasserkostenInput) -> WasserkostenErgebnis {
        let summe = input.verbrauchProEinheitM3.values.reduce(0 as Decimal, +)
        let preis: Euro = summe == 0 ? 0 : input.bwbGesamtkostenEuro / summe

        let einheitIDs = input.verbrauchProEinheitM3.keys.sorted()
        let proEinheit: [WasserkostenErgebnisEinheit] = einheitIDs.map { id in
            let verbrauch = input.verbrauchProEinheitM3[id] ?? 0
            return WasserkostenErgebnisEinheit(
                einheitID: id,
                verbrauchM3: verbrauch,
                anteilEuro: verbrauch * preis
            )
        }

        return WasserkostenErgebnis(
            bwbGesamtkostenEuro: input.bwbGesamtkostenEuro,
            summeEinzelverbrauchM3: summe,
            kombiPreisEuroProM3: preis,
            proEinheit: proEinheit
        )
    }
}
