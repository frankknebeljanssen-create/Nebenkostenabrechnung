//
//  FlaechenRechner.swift
//  NebenkostenApp — Calc-Layer
//
//  Generische Flächen-Umlage eines Basisbetrags auf Wohn-/Nutzeinheiten
//  strikt nach m²-Anteil an der Gesamtfläche. Einsatzgebiete laut
//  BetrKV §2: Grundsteuer (Nr. 1), Versicherung (Nr. 13), Straßenreinigung
//  und Müllabfuhr (Nr. 8), Allgemeinstrom (Nr. 11) u.a.
//  Einziger erlaubter Import: Foundation.
//

import Foundation

struct FlaechenInput: Equatable, Sendable {
    /// Umzulegender Gesamtbetrag in Euro.
    let basisBetragEuro: Euro
    /// Gesamtfläche der Liegenschaft in m² (Summe aller Einheiten,
    /// inkl. Gewerbe und Leerstand).
    let gesamtflaecheM2: Flaeche
    /// Fläche pro Einheit in m².
    let flaechenProEinheit: [String: Flaeche]

    init(
        basisBetragEuro: Euro,
        gesamtflaecheM2: Flaeche,
        flaechenProEinheit: [String: Flaeche]
    ) {
        self.basisBetragEuro = basisBetragEuro
        self.gesamtflaecheM2 = gesamtflaecheM2
        self.flaechenProEinheit = flaechenProEinheit
    }
}

struct FlaechenErgebnisEinheit: Equatable, Sendable {
    let einheitID: String
    let flaecheM2: Flaeche
    let anteilEuro: Euro
    /// z.B. "160/528 m²"
    let verteilerschluesselText: String
}

struct FlaechenErgebnis: Equatable, Sendable {
    let basisBetragEuro: Euro
    let gesamtflaecheM2: Flaeche
    let proEinheit: [FlaechenErgebnisEinheit]
}

enum FlaechenRechner {

    /// Verteilt `basisBetragEuro` proportional zur Fläche jeder Einheit:
    ///     anteilEuro = basis · einheitFlaeche / gesamtflaeche
    /// Intern Decimal voller Präzision — die Summe der unrundeten
    /// Anteile entspricht exakt dem Basisbetrag (algebraisch Σ(x/y)=1).
    static func berechne(_ input: FlaechenInput) -> FlaechenErgebnis {
        let gesamtTexteil = formatteFlaeche(input.gesamtflaecheM2)

        let einheitIDs = input.flaechenProEinheit.keys.sorted()
        let proEinheit: [FlaechenErgebnisEinheit] = einheitIDs.map { id in
            let flaeche = input.flaechenProEinheit[id] ?? 0
            let anteil: Euro = input.gesamtflaecheM2 == 0
                ? 0
                : input.basisBetragEuro * flaeche / input.gesamtflaecheM2
            let text = "\(formatteFlaeche(flaeche))/\(gesamtTexteil) m²"
            return FlaechenErgebnisEinheit(
                einheitID: id,
                flaecheM2: flaeche,
                anteilEuro: anteil,
                verteilerschluesselText: text
            )
        }

        return FlaechenErgebnis(
            basisBetragEuro: input.basisBetragEuro,
            gesamtflaecheM2: input.gesamtflaecheM2,
            proEinheit: proEinheit
        )
    }

    /// Ganzzahlig wenn exakt, sonst eine Nachkommastelle.
    private static func formatteFlaeche(_ wert: Flaeche) -> String {
        let ganzzahlig = wert.gerundet(auf: 0, modus: .abrunden)
        if wert == ganzzahlig {
            return NSDecimalNumber(decimal: ganzzahlig).stringValue
        }
        let gerundet = wert.gerundet(auf: 1, modus: .bankers)
        return NSDecimalNumber(decimal: gerundet).stringValue
    }
}
