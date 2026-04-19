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

    // MARK: - Bahnhofstr. 37 — Integration mit JSON v1.2

    @Test("Bahnhofstr. 37 — §9-Split Zwischenwerte matchen OG-Excel-Referenz")
    func bahnhofstr37_neunParagrafSplit() throws {
        let daten = try Bahnhofstr37.laden()
        let gasag = daten.rechnung("gasag_2024_2025")
        let heizung = daten.objekt.heizung!
        let v = daten.zaehlerstaende.verbraeuche_berechnet

        let parameter = HeizkostenParameter(
            wwGasFaktor:             heizung.ww_gas_faktor_m3_pro_m3!,
            brennwertKwhProM3:       heizung.brennwert_z_zahl_kwh_pro_m3!,
            stromZuschlagProzent:    heizung.strom_hilfsenergie_prozent! / 100,
            aufteilungHeizungProzent: heizung.grundkosten_anteil_prozent! / 100,
            internerArbeitspreisEuroProKwh: NSDecimalNumber(decimal: gasag.interner_arbeitspreis_berechnung!).doubleValue
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: NSDecimalNumber(decimal: gasag.verbrauch_kwh!).doubleValue,
            gesamtGasKostenBrutto: gasag.gesamt_brutto,
            heizNebenkosten: daten.heiz_nebenkosten_zusammensetzung!.summe_2024_2025,
            wwNebenkosten: 0,
            wmzProEinheit: [
                "KG": NSDecimalNumber(decimal: v.wmz_kg_kwh!).doubleValue,
                "EG": NSDecimalNumber(decimal: v.wmz_eg_kwh!).doubleValue,
                "OG": NSDecimalNumber(decimal: v.wmz_og_kwh!).doubleValue
            ],
            wwM3ProEinheit: [
                "KG": NSDecimalNumber(decimal: v.ww_kg_m3!).doubleValue,
                "EG": NSDecimalNumber(decimal: v.ww_eg_m3!).doubleValue,
                "OG": NSDecimalNumber(decimal: v.ww_og_m3!).doubleValue
            ],
            flaechenProEinheit: [
                "KG": NSDecimalNumber(decimal: daten.einheit("KG").flaeche_qm).doubleValue,
                "EG": NSDecimalNumber(decimal: daten.einheit("EG").flaeche_qm).doubleValue,
                "OG": NSDecimalNumber(decimal: daten.einheit("OG").flaeche_qm).doubleValue
            ],
            parameter: parameter
        )

        let e = HeizkostenRechner.berechne(input)

        print("""

        ── Bahnhofstr. 37 §9-HeizkostenV-Diagnostik (JSON v1.2) ──
          WW-Gesamt-m³:              \(input.wwM3ProEinheit.values.reduce(0, +)) m³
          WW-Gas-kWh (qWwKwh):       \(e.qWarmwasserGesamtKwh) kWh  (Ref OG-Excel: 9906,21)
          Heizungs-kWh (qHeizungKwh): \(e.qHeizungKwh) kWh           (Ref: 32257 − 9906,21)

          Gas-Kosten brutto:         \(input.gesamtGasKostenBrutto) €
          Interner Arbeitspreis:     \(parameter.internerArbeitspreisEuroProKwh!) €/kWh

          gasKostenWw = 9906,21 · 0,104255:
          → WW-Topf (vor Strom/NK):  \(e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers).magnitude) €
                                     ... + 3 % Strom  + wwNebenkosten 0 €
          → WW-Topf (fertig):        \(e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers)) €
                                     (Ref OG-Excel ww_gaskosten_brutto: 1032,77 € · 1,03 = 1063,75 €)

          → Heiz-Topf (fertig, inkl. 418,85 € NK):
                                     \(e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers)) €

          30 % Grundkosten (m²) / 70 % Verbrauch (WMZ für Heizung, WW-m³ für Warmwasser):
        """)
        for einheit in e.proEinheit.sorted(by: { $0.einheitID < $1.einheitID }) {
            let hg = einheit.heizung.gesamtEuro.gerundet(auf: 2, modus: .bankers)
            let wg = einheit.warmwasser.gesamtEuro.gerundet(auf: 2, modus: .bankers)
            let gs = (einheit.heizung.gesamtEuro + einheit.warmwasser.gesamtEuro).gerundet(auf: 2, modus: .bankers)
            print("    \(einheit.einheitID): Heizung \(hg) €  +  Warmwasser \(wg) €  =  \(gs) €")
        }
        print("""
          (Ref OG-Excel og_gesamtabrechnung.ww_heizung: 1997,06 €  —
           weicht ab, solange wwNebenkosten und exakte Strom-Zuordnung offen.)
        ────────────────────────────────────────────────────────
        """)

        // OG-Excel-Referenz-Matches (entspricht §9-Split):
        //   WW-Gas-kWh sollte 9906,21 kWh entsprechen.
        let qWwGerundet = Decimal(e.qWarmwasserGesamtKwh).gerundet(auf: 2, modus: .bankers)
        let qWwAbweichung = (qWwGerundet - Decimal(string: "9906.21")!).magnitude
        #expect(qWwAbweichung < Decimal(string: "0.01")!)

        //   WW-Gaskosten brutto (VOR Strom/NK) sollte 1032,77 € entsprechen.
        //   Wir rekonstruieren den Wert aus dem Topf (1063,75 − 30,98 Strom = 1032,77).
        let stromZuschlag = Decimal(parameter.stromZuschlagProzent)
        let gasKostenWwRekonstruiert = e.warmwasserkostenTopfEuro / (1 + stromZuschlag)
        let gaskostenGerundet = gasKostenWwRekonstruiert.gerundet(auf: 2, modus: .bankers)
        let gaskostenAbweichung = (gaskostenGerundet - Decimal(string: "1032.77")!).magnitude
        #expect(gaskostenAbweichung < Decimal(string: "0.02")!)
    }

    @Test("Bahnhofstr. 37 — Summen-Erhaltung pro Einheit = Topf-Summe")
    func bahnhofstr37_summenErhaltung() throws {
        let daten = try Bahnhofstr37.laden()
        let gasag = daten.rechnung("gasag_2024_2025")
        let heizung = daten.objekt.heizung!
        let v = daten.zaehlerstaende.verbraeuche_berechnet

        let parameter = HeizkostenParameter(
            wwGasFaktor:             heizung.ww_gas_faktor_m3_pro_m3!,
            brennwertKwhProM3:       heizung.brennwert_z_zahl_kwh_pro_m3!,
            stromZuschlagProzent:    heizung.strom_hilfsenergie_prozent! / 100,
            aufteilungHeizungProzent: heizung.grundkosten_anteil_prozent! / 100,
            internerArbeitspreisEuroProKwh: NSDecimalNumber(decimal: gasag.interner_arbeitspreis_berechnung!).doubleValue
        )
        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: NSDecimalNumber(decimal: gasag.verbrauch_kwh!).doubleValue,
            gesamtGasKostenBrutto: gasag.gesamt_brutto,
            heizNebenkosten: daten.heiz_nebenkosten_zusammensetzung!.summe_2024_2025,
            wwNebenkosten: 0,
            wmzProEinheit: [
                "KG": NSDecimalNumber(decimal: v.wmz_kg_kwh!).doubleValue,
                "EG": NSDecimalNumber(decimal: v.wmz_eg_kwh!).doubleValue,
                "OG": NSDecimalNumber(decimal: v.wmz_og_kwh!).doubleValue
            ],
            wwM3ProEinheit: [
                "KG": NSDecimalNumber(decimal: v.ww_kg_m3!).doubleValue,
                "EG": NSDecimalNumber(decimal: v.ww_eg_m3!).doubleValue,
                "OG": NSDecimalNumber(decimal: v.ww_og_m3!).doubleValue
            ],
            flaechenProEinheit: [
                "KG": NSDecimalNumber(decimal: daten.einheit("KG").flaeche_qm).doubleValue,
                "EG": NSDecimalNumber(decimal: daten.einheit("EG").flaeche_qm).doubleValue,
                "OG": NSDecimalNumber(decimal: daten.einheit("OG").flaeche_qm).doubleValue
            ],
            parameter: parameter
        )
        let e = HeizkostenRechner.berechne(input)

        let heizSumme = e.proEinheit.reduce(Decimal(0)) { $0 + $1.heizung.gesamtEuro }
        let wwSumme   = e.proEinheit.reduce(Decimal(0)) { $0 + $1.warmwasser.gesamtEuro }

        #expect(heizSumme.gerundet(auf: 2, modus: .bankers)
             == e.heizkostenTopfEuro.gerundet(auf: 2, modus: .bankers))
        #expect(wwSumme.gerundet(auf: 2, modus: .bankers)
             == e.warmwasserkostenTopfEuro.gerundet(auf: 2, modus: .bankers))
    }
}
