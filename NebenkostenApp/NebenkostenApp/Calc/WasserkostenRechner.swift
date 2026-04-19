//
//  WasserkostenRechner.swift
//  NebenkostenApp — Calc-Layer
//
//  Verteilung der BWB-Kosten (Trinkwasser + Schmutzwasser) auf die
//  Einheiten nach verbrauchtem m³ am jeweiligen Wohnungs-Kaltwasser-
//  zähler. Warmwasser zählt als Trinkwasser (weil aus demselben
//  Hauptzähler entnommen) und fließt in den Einheits-Verbrauch ein.
//  Gartenzwischenzähler reduzieren ausschließlich den Abwasseranteil
//  (Bewässerung verlässt die Liegenschaft, keine Schmutzwasser-Gebühr).
//
//  Einziger erlaubter Import: Foundation.
//

import Foundation

struct WasserkostenInput: Equatable, Sendable {
    /// Trinkwasser-Gesamtverbrauch der Liegenschaft in m³ (BWB-Hauptzähler).
    let verbrauchGesamtM3: Verbrauch
    /// Trinkwasserkosten brutto (Mengenpreis · m³ + Grundgebühr).
    let trinkwasserKostenEuro: Euro
    /// Schmutzwasserkosten brutto (Mengenpreis · m³ reduziert um Garten
    /// + Grundgebühr).
    let schmutzwasserKostenEuro: Euro
    /// Einheit-Verbrauch in m³ (Kaltwasser-Wohnungszähler-Differenz plus
    /// Warmwasser-Verbrauch, da Warmwasser aus demselben Hauptzähler
    /// gezogen wird).
    let verbrauchProEinheitM3: [String: Verbrauch]
    /// Gartenzwischenzähler-Verbrauch pro Einheit. Wird NUR beim
    /// Abwasser abgezogen — Trinkwasser wird trotzdem verrechnet.
    /// Für Bahnhofstr. 37: `["EG": 191]`.
    let gartenM3ProEinheit: [String: Verbrauch]

    init(
        verbrauchGesamtM3: Verbrauch,
        trinkwasserKostenEuro: Euro,
        schmutzwasserKostenEuro: Euro,
        verbrauchProEinheitM3: [String: Verbrauch],
        gartenM3ProEinheit: [String: Verbrauch] = [:]
    ) {
        self.verbrauchGesamtM3 = verbrauchGesamtM3
        self.trinkwasserKostenEuro = trinkwasserKostenEuro
        self.schmutzwasserKostenEuro = schmutzwasserKostenEuro
        self.verbrauchProEinheitM3 = verbrauchProEinheitM3
        self.gartenM3ProEinheit = gartenM3ProEinheit
    }
}

struct WasserkostenPosition: Equatable, Sendable {
    let trinkwasserEuro: Euro
    let schmutzwasserEuro: Euro
    let gesamtEuro: Euro
}

struct WasserkostenErgebnisEinheit: Equatable, Sendable {
    let einheitID: String
    /// Trinkwasser-Verbrauch der Einheit (inkl. Garten).
    let verbrauchM3: Verbrauch
    /// Abwasser-relevanter Verbrauch (Trinkwasser − Gartenzwischen).
    let schmutzwasserM3: Verbrauch
    let position: WasserkostenPosition
}

struct WasserkostenErgebnis: Equatable, Sendable {
    /// Kaltwasser gesamt in m³ (BWB-Hauptzähler).
    let trinkwasserGesamtM3: Verbrauch
    /// Abwasser-relevante Menge in m³ (Trinkwasser − Summe Garten).
    let schmutzwasserGesamtM3: Verbrauch
    /// Summe aller Gartenzwischenzähler in m³.
    let gartenGesamtM3: Verbrauch
    let proEinheit: [WasserkostenErgebnisEinheit]
}

enum WasserkostenRechner {

    /// Verteilt die BWB-Kosten proportional zum m³-Verbrauch:
    ///   Trinkwasserkosten pro Einheit   = TK · einheitVerbrauch / Σ Verbrauch
    ///   Schmutzwasserkosten pro Einheit = SK · (einheitVerbrauch − Garten)
    ///                                        / (Σ Verbrauch − Σ Garten)
    /// Intern Decimal voller Präzision; Cent-Rundung obliegt dem Aufrufer.
    static func berechne(_ input: WasserkostenInput) -> WasserkostenErgebnis {
        let gartenGesamt = input.gartenM3ProEinheit.values.reduce(0 as Decimal, +)
        let schmutzwasserGesamt = input.verbrauchGesamtM3 - gartenGesamt

        let einheitIDs = Set(input.verbrauchProEinheitM3.keys)
            .union(input.gartenM3ProEinheit.keys)
            .sorted()

        let proEinheit: [WasserkostenErgebnisEinheit] = einheitIDs.map { id in
            let verbrauch = input.verbrauchProEinheitM3[id] ?? 0
            let garten = input.gartenM3ProEinheit[id] ?? 0
            let schmutzwasserEinheit = verbrauch - garten

            let trinkwasserAnteil = input.verbrauchGesamtM3 == 0
                ? 0
                : input.trinkwasserKostenEuro * verbrauch / input.verbrauchGesamtM3
            let schmutzwasserAnteil = schmutzwasserGesamt == 0
                ? 0
                : input.schmutzwasserKostenEuro * schmutzwasserEinheit / schmutzwasserGesamt

            return WasserkostenErgebnisEinheit(
                einheitID: id,
                verbrauchM3: verbrauch,
                schmutzwasserM3: schmutzwasserEinheit,
                position: WasserkostenPosition(
                    trinkwasserEuro: trinkwasserAnteil,
                    schmutzwasserEuro: schmutzwasserAnteil,
                    gesamtEuro: trinkwasserAnteil + schmutzwasserAnteil
                )
            )
        }

        return WasserkostenErgebnis(
            trinkwasserGesamtM3: input.verbrauchGesamtM3,
            schmutzwasserGesamtM3: schmutzwasserGesamt,
            gartenGesamtM3: gartenGesamt,
            proEinheit: proEinheit
        )
    }
}
