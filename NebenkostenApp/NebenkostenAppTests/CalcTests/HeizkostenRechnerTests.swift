//
//  HeizkostenRechnerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Testet §9-Split + 30/70-Verteilung nach §7 HeizkostenV.
//

import Foundation
import Testing
@testable import NebenkostenApp

struct HeizkostenRechnerTests {

    // MARK: - Synthetische Immobilie: §9-Split + Verteilung sauber isoliert

    /// Referenz-Szenario, Zahlen absichtlich "rund":
    ///   2 Einheiten, Flächen 100 und 200 m² (Gesamt 300).
    ///   GAS: 10 000 kWh, 1000 € brutto.
    ///   WW-Verbrauch: 10 und 20 m³ (Summe 30).
    ///   WW-Gas-Faktor 10, Brennwert 10 → Q_WW = 30·10·10 = 3000 kWh.
    ///   → Heizung 7000 kWh, Gas-Kosten splitten 30/70.
    ///   Nach §9: gasKostenWw = 300, gasKostenHeizung = 700.
    ///   +Stromzuschlag 0 (deaktiviert): unverändert.
    ///   Nebenkosten: heiz 100, ww 50.
    ///   → heizkostenTopf = 800, warmwasserkostenTopf = 350.
    ///
    ///   §7 30/70 auf Einheit "A" (100 m², WMZ 3000 kWh, WW 10 m³):
    ///     Heizung A: Flächenanteil  = 800·0,30·100/300 = 80
    ///                Verbrauch      = 800·0,70·3000/7000 = 240
    ///                                  (da Σ WMZ = 7000 = Q_Heizung)
    ///                Gesamt         = 320
    ///     WW      A: Flächenanteil  = 350·0,30·100/300 = 35
    ///                Verbrauch      = 350·0,70·10/30   = 81,666…
    ///                Gesamt         = 116,666…  → 116,67 (bankers)
    ///
    ///   Einheit "B" analog mit 200 m², WMZ 4000, WW 20 m³.
    @Test("Referenz-Szenario: §9-Split + §7-Verteilung, 2 Einheiten, runde Zahlen")
    func referenz_zweiEinheiten() {
        let parameter = HeizkostenParameter(
            wwGasFaktor: 10,
            brennwertKwhProM3: 10,
            stromZuschlagProzent: 0,
            aufteilungHeizungProzent: 0.30
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: 10_000,
            gesamtGasKostenBrutto: 1_000,
            heizNebenkosten: 100,
            wwNebenkosten: 50,
            wmzProEinheit:    ["A": 3_000, "B": 4_000],
            wwM3ProEinheit:   ["A": 10,    "B": 20],
            flaechenProEinheit: ["A": 100, "B": 200],
            parameter: parameter
        )

        let e = HeizkostenRechner.berechne(input)

        // §9-Split
        #expect(e.qWarmwasserGesamtKwh == 3_000)
        #expect(e.qHeizungKwh          == 7_000)
        #expect(e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers)       == 800)
        #expect(e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers) == 350)

        // Einheit A
        let a = e.proEinheit.first { $0.einheitID == "A" }!
        #expect(a.heizung.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers)   == 80)
        #expect(a.heizung.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == 240)
        #expect(a.heizung.gesamtEuro.gerundet(auf: 2, modus: .bankers)            == 320)
        #expect(a.warmwasser.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers) == 35)
        #expect(a.warmwasser.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "81.67"))
        #expect(a.warmwasser.gesamtEuro.gerundet(auf: 2, modus: .bankers)         == Decimal(string: "116.67"))

        // Einheit B
        let b = e.proEinheit.first { $0.einheitID == "B" }!
        #expect(b.heizung.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers)    == 160)
        #expect(b.heizung.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers)  == 320)
        #expect(b.heizung.gesamtEuro.gerundet(auf: 2, modus: .bankers)             == 480)
        #expect(b.warmwasser.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers)  == 70)
        #expect(b.warmwasser.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "163.33"))
        #expect(b.warmwasser.gesamtEuro.gerundet(auf: 2, modus: .bankers)          == Decimal(string: "233.33"))
    }

    // MARK: - Stromzuschlag separat geprüft

    @Test("Stromzuschlag 3 % erhöht beide Töpfe um denselben Faktor")
    func stromZuschlag() {
        let parameter = HeizkostenParameter(
            wwGasFaktor: 10,
            brennwertKwhProM3: 10,
            stromZuschlagProzent: 0.03,
            aufteilungHeizungProzent: 0.30
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: 10_000,
            gesamtGasKostenBrutto: 1_000,
            heizNebenkosten: 0,
            wwNebenkosten: 0,
            wmzProEinheit:    ["A": 7_000],
            wwM3ProEinheit:   ["A": 30],
            flaechenProEinheit: ["A": 100],
            parameter: parameter
        )
        let e = HeizkostenRechner.berechne(input)

        // Ohne Strom: 700/300. Mit 3 %: 721,00 / 309,00. Summe: 1030,00.
        #expect(e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers)       == 721)
        #expect(e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers) == 309)
    }

    // MARK: - Nebenkosten fließen in getrennte Töpfe

    @Test("Heizungs- und Warmwasser-Nebenkosten fließen in getrennte Töpfe")
    func getrennteNebenkosten() {
        let parameter = HeizkostenParameter(
            wwGasFaktor: 10, brennwertKwhProM3: 10,
            stromZuschlagProzent: 0, aufteilungHeizungProzent: 0.30
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: 10_000,
            gesamtGasKostenBrutto: 1_000,
            heizNebenkosten: 200,  // z.B. Schornsteinfeger + Wartung
            wwNebenkosten:   80,  // z.B. Legionellenprüfung
            wmzProEinheit:    ["A": 7_000],
            wwM3ProEinheit:   ["A": 30],
            flaechenProEinheit: ["A": 100],
            parameter: parameter
        )
        let e = HeizkostenRechner.berechne(input)
        // 700 + 200 = 900 | 300 + 80 = 380
        #expect(e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers)       == 900)
        #expect(e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers) == 380)
    }

    // MARK: - Summen-Erhaltung: Σ proEinheit == Topf

    @Test("Summe der Einheits-Positionen ergibt die Topf-Beträge")
    func summenErhaltung() {
        let parameter = HeizkostenParameter(
            wwGasFaktor: 10, brennwertKwhProM3: 10,
            stromZuschlagProzent: 0.03, aufteilungHeizungProzent: 0.30
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: 32_257,
            gesamtGasKostenBrutto: Decimal(string: "3554.95")!,
            heizNebenkosten: Decimal(string: "150")!,
            wwNebenkosten:   Decimal(string: "40")!,
            wmzProEinheit:    ["KG": 8_319, "EG": 8_100, "OG": 9_499],
            wwM3ProEinheit:   ["KG": 0.37,  "EG": 28.45, "OG": 29.25],
            flaechenProEinheit: ["KG": 160, "EG": 181,   "OG": 187],
            parameter: parameter
        )
        let e = HeizkostenRechner.berechne(input)

        let heizungsSumme = e.proEinheit.reduce(Decimal(0)) { $0 + $1.heizung.gesamtEuro }
        let wwSumme       = e.proEinheit.reduce(Decimal(0)) { $0 + $1.warmwasser.gesamtEuro }

        #expect(heizungsSumme.gerundet(auf: 2, modus: .bankers)
             == e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers))
        #expect(wwSumme.gerundet(auf: 2, modus: .bankers)
             == e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers))
    }

    // MARK: - Bahnhofstr. 37 — blockiert bis heizNK/wwNK/EG-WMZ geklärt

    @Test(
        "Bahnhofstr. 37 KG+OG (blocked: heizNK, wwNK, EG-WMZ offen)",
        .disabled("Input-Werte heizNebenkosten, wwNebenkosten und wmz_eg_kwh fehlen in Testdaten-JSON bzw. sind unklar.")
    )
    func bahnhofstr37_kgOg() throws {
        // Wird aktiviert, sobald User Heizungs-Nebenkosten, Warmwasser-
        // Nebenkosten und EG-WMZ-Anfangsstand liefert.
    }
}
