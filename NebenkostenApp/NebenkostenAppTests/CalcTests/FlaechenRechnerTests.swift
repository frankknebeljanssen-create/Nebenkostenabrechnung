//
//  FlaechenRechnerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Generische m²-Umlage (Grundsteuer, Versicherung, BSR etc.).
//

import Foundation
import Testing
@testable import NebenkostenApp

struct FlaechenRechnerTests {

    // MARK: - Gleichverteilung

    @Test("Drei gleich große Einheiten bekommen je ein Drittel")
    func gleichverteilung() {
        let input = FlaechenInput(
            basisBetragEuro: 300,
            gesamtflaecheM2: 300,
            flaechenProEinheit: ["A": 100, "B": 100, "C": 100]
        )
        let e = FlaechenRechner.berechne(input)

        for einheit in e.proEinheit {
            #expect(einheit.anteilEuro.gerundet(auf: 2, modus: .bankers) == 100)
        }
    }

    // MARK: - Summen-Erhaltung (Akzeptanzkriterium Task 0.6)

    @Test("Akzeptanzkriterium: Σ Anteile = Basisbetrag (Toleranz 0,01 €)")
    func summenErhaltung() {
        let input = FlaechenInput(
            basisBetragEuro: Decimal(string: "3355.89")!,
            gesamtflaecheM2: 528,
            flaechenProEinheit: ["KG": 160, "EG": 181, "OG": 187]
        )
        let e = FlaechenRechner.berechne(input)

        // Unrundete Summe: liegt wegen Decimal-38-Stellen-Präzision auf
        // ULP-Niveau (~10⁻³⁶ €) am Basisbetrag. Mit Mini-Toleranz prüfen.
        let summeUnrundet = e.proEinheit.reduce(Decimal(0)) { $0 + $1.anteilEuro }
        let ulpAbweichung = (summeUnrundet - input.basisBetragEuro).magnitude
        #expect(ulpAbweichung < Decimal(string: "0.000001")!)

        // Gerundete Summe (Cent-Ebene, was auf der Abrechnung steht):
        let summeGerundet = e.proEinheit.reduce(Decimal(0)) {
            $0 + $1.anteilEuro.gerundet(auf: 2, modus: .bankers)
        }
        let abweichung = (summeGerundet - input.basisBetragEuro).magnitude
        #expect(abweichung <= Decimal(string: "0.01")!)
    }

    // MARK: - Bahnhofstr. 37 Grundsteuer 2025

    @Test("Bahnhofstr. 37 Grundsteuer 3355,89 € — m²-Anteile")
    func bahnhofstr37_grundsteuer() {
        let input = FlaechenInput(
            basisBetragEuro: Decimal(string: "3355.89")!,
            gesamtflaecheM2: 528,
            flaechenProEinheit: ["KG": 160, "EG": 181, "OG": 187]
        )
        let e = FlaechenRechner.berechne(input)

        let kg = e.proEinheit.first { $0.einheitID == "KG" }!
        let eg = e.proEinheit.first { $0.einheitID == "EG" }!
        let og = e.proEinheit.first { $0.einheitID == "OG" }!

        // Reine m²-Umlage, Cent bankers:
        //   KG: 3355,89 · 160/528 = 1016,94
        //   EG: 3355,89 · 181/528 = 1150,41
        //   OG: 3355,89 · 187/528 = 1188,54
        //   Σ  = 3355,89 exakt
        //
        // JSON-Referenzwerte (erwartete_ergebnisse.grundsteuer_umlage_m2)
        // weichen bei EG/OG um ±0,16 € ab (Summen-Check passt). Wir folgen
        // der mathematisch exakten Rechnung; eine Anpassung der JSON-
        // Referenzwerte klären wir separat.
        #expect(kg.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "1016.94"))
        #expect(eg.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "1150.41"))
        #expect(og.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "1188.54"))

        #expect(kg.verteilerschluesselText == "160/528 m²")
        #expect(eg.verteilerschluesselText == "181/528 m²")
        #expect(og.verteilerschluesselText == "187/528 m²")
    }

    // MARK: - Bahnhofstr. 37 Versicherung 2024/2025

    @Test("Bahnhofstr. 37 Allianz-Versicherung 2115,13 € — m²-Anteile")
    func bahnhofstr37_versicherung() {
        let input = FlaechenInput(
            basisBetragEuro: Decimal(string: "2115.13")!,
            gesamtflaecheM2: 528,
            flaechenProEinheit: ["KG": 160, "EG": 181, "OG": 187]
        )
        let e = FlaechenRechner.berechne(input)

        // Exakte m²-Rechnung (bankers auf 2 Stellen):
        //   KG: 2115,13 · 160/528 =  640,95
        //   EG: 2115,13 · 181/528 =  725,07
        //   OG: 2115,13 · 187/528 =  749,11  (deckt die JSON-Referenz 749,11)
        //   Σ = 2115,13 (bis auf Decimal-ULP)
        //
        // Die JSON-Referenz `m2_umlagen_ref.versicherung` (KG 640,95 /
        // EG 725,40 / OG 748,78) stammt aus einer früheren Excel-Rechnung
        // und weicht bei EG/OG ab — siehe JSON-Hinweis "Abweichung durch
        // Rundung, bestätigte OG-Referenz 749,11".
        let summe = e.proEinheit.reduce(Decimal(0)) { $0 + $1.anteilEuro }
        let summeAbweichung = (summe - input.basisBetragEuro).magnitude
        #expect(summeAbweichung < Decimal(string: "0.000001")!)

        let kg = e.proEinheit.first { $0.einheitID == "KG" }!
        let eg = e.proEinheit.first { $0.einheitID == "EG" }!
        let og = e.proEinheit.first { $0.einheitID == "OG" }!
        #expect(kg.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "640.95"))
        #expect(eg.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "725.07"))
        #expect(og.anteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "749.11"))
    }

    // MARK: - Edge Cases

    @Test("Einheit mit 0 m² bekommt 0 €")
    func leereEinheit() {
        let input = FlaechenInput(
            basisBetragEuro: 100,
            gesamtflaecheM2: 100,
            flaechenProEinheit: ["A": 100, "B": 0]
        )
        let e = FlaechenRechner.berechne(input)
        let b = e.proEinheit.first { $0.einheitID == "B" }!
        #expect(b.anteilEuro == 0)
    }

    @Test("Gesamtfläche 0 liefert 0 € für alle (keine Division durch 0)")
    func gesamtflaecheNull() {
        let input = FlaechenInput(
            basisBetragEuro: 100,
            gesamtflaecheM2: 0,
            flaechenProEinheit: ["A": 0, "B": 0]
        )
        let e = FlaechenRechner.berechne(input)
        for einheit in e.proEinheit {
            #expect(einheit.anteilEuro == 0)
        }
    }
}
