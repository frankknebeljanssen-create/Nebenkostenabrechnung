//
//  AbrechnungsAggregatorTests.swift
//  NebenkostenAppTests — CalcTests
//

import Foundation
import Testing
@testable import NebenkostenApp

struct AbrechnungsAggregatorTests {

    // MARK: - Minimal-Integration: Grundsteuer allein

    @Test("Flächenumlage einzeln: 3 Einheiten bekommen je eine Position")
    func minimalFlaechenumlage() {
        let input = AbrechnungsInput(
            einheitIDs: ["A", "B", "C"],
            positionen: [
                .flaechenumlage(
                    kostenart: "Grundsteuer",
                    FlaechenInput(
                        basisBetragEuro: 300,
                        gesamtflaecheM2: 300,
                        flaechenProEinheit: ["A": 100, "B": 100, "C": 100]
                    )
                )
            ]
        )
        let e = AbrechnungsAggregator.aggregiere(input)
        #expect(e.proEinheit.count == 3)
        for id in ["A", "B", "C"] {
            #expect(e.proEinheit[id]!.count == 1)
            #expect(e.proEinheit[id]![0].kostenart == "Grundsteuer")
            #expect(e.proEinheit[id]![0].mieteranteilEuro.gerundet(auf: 2, modus: .bankers) == 100)
        }
    }

    // MARK: - Mehrere Kostenarten zusammen

    @Test("Drei Kostenarten gleichzeitig: Flächenumlage + Wasser + Direkt")
    func mehrereKostenarten() {
        let input = AbrechnungsInput(
            einheitIDs: ["A", "B"],
            positionen: [
                .flaechenumlage(
                    kostenart: "Grundsteuer",
                    FlaechenInput(basisBetragEuro: 200, gesamtflaecheM2: 200,
                                  flaechenProEinheit: ["A": 100, "B": 100])
                ),
                .wasser(
                    WasserkostenInput(bwbGesamtkostenEuro: 300,
                                      verbrauchProEinheitM3: ["A": 100, "B": 200])
                ),
                .direkt(kostenart: "Einzelreparatur",
                        einheitID: "A",
                        betrag: 50,
                        text: "100 % Einheit A (Verursacher)")
            ]
        )
        let e = AbrechnungsAggregator.aggregiere(input)

        // A hat 3 Positionen, B hat 2
        #expect(e.proEinheit["A"]!.count == 3)
        #expect(e.proEinheit["B"]!.count == 2)

        // A Summe: 100 Grundsteuer + 100 Wasser (100/300 · 300) + 50 Direkt = 250
        #expect(e.summe(fuer: "A").gerundet(auf: 2, modus: .bankers) == 250)
        // B Summe: 100 Grundsteuer + 200 Wasser (200/300 · 300) = 300
        #expect(e.summe(fuer: "B").gerundet(auf: 2, modus: .bankers) == 300)
    }

    // MARK: - Heizkosten-Integration

    @Test("Heizkosten-Case: pro Einheit zwei Positionen (Heizung + Warmwasser)")
    func heizkostenErzeugtZweiPositionen() {
        let parameter = HeizkostenParameter(
            wwGasFaktor: 10, brennwertKwhProM3: 10,
            stromZuschlagProzent: 0, aufteilungHeizungProzent: 0.30
        )
        let heizInput = HeizkostenInput(
            gesamtGasVerbrauchKwh: 10_000,
            gesamtGasKostenBrutto: 1_000,
            heizNebenkosten: 0,
            wwNebenkosten: 0,
            wmzProEinheit: ["A": 5_000, "B": 2_000],
            wwM3ProEinheit: ["A": 15, "B": 15],
            flaechenProEinheit: ["A": 100, "B": 200],
            parameter: parameter
        )
        let input = AbrechnungsInput(
            einheitIDs: ["A", "B"],
            positionen: [.heizkosten(heizInput)]
        )
        let e = AbrechnungsAggregator.aggregiere(input)

        for id in ["A", "B"] {
            #expect(e.proEinheit[id]!.count == 2)
            let kostenarten = e.proEinheit[id]!.map(\.kostenart)
            #expect(kostenarten.contains("Heizung"))
            #expect(kostenarten.contains("Warmwasser"))
        }
    }

    // MARK: - Bahnhofstr. 37 — große Vier zusammen

    @Test("Bahnhofstr. 37 — Heizung+WW, Wasser, Grundsteuer, Versicherung zusammen")
    func bahnhofstr37_grosseVier() throws {
        let daten = try Bahnhofstr37.laden()
        let gasag = daten.rechnung("gasag_2024_2025")
        let bwb = daten.rechnung("bwb_2024_2025")
        let heizung = daten.objekt.heizung!
        let v = daten.zaehlerstaende.verbraeuche_berechnet
        let flaecheKG = daten.einheit("KG").flaeche_qm
        let flaecheEG = daten.einheit("EG").flaeche_qm
        let flaecheOG = daten.einheit("OG").flaeche_qm

        let heizParameter = HeizkostenParameter(
            wwGasFaktor:             heizung.ww_gas_faktor_m3_pro_m3!,
            brennwertKwhProM3:       heizung.brennwert_z_zahl_kwh_pro_m3!,
            stromZuschlagProzent:    heizung.strom_hilfsenergie_prozent! / 100,
            aufteilungHeizungProzent: heizung.grundkosten_anteil_prozent! / 100,
            internerArbeitspreisEuroProKwh: NSDecimalNumber(decimal: gasag.interner_arbeitspreis_berechnung!).doubleValue
        )
        let heizInput = HeizkostenInput(
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
                "KG": NSDecimalNumber(decimal: flaecheKG).doubleValue,
                "EG": NSDecimalNumber(decimal: flaecheEG).doubleValue,
                "OG": NSDecimalNumber(decimal: flaecheOG).doubleValue
            ],
            parameter: heizParameter
        )

        let wasserInput = WasserkostenInput(
            bwbGesamtkostenEuro: bwb.gesamt_brutto,
            verbrauchProEinheitM3: [
                "KG": (v.kw_kg_m3 ?? 0) + (v.ww_kg_m3 ?? 0),
                "EG": (v.kw_eg_m3 ?? 0) + (v.ww_eg_m3 ?? 0),
                "OG": (v.kw_og_m3 ?? 0) + (v.ww_og_m3 ?? 0)
            ]
        )
        let grundsteuer = daten.rechnung("grundsteuer_2025").gesamt_brutto
        let versicherung = daten.rechnung("allianz_2024_2025").gesamt_brutto

        let input = AbrechnungsInput(
            einheitIDs: ["KG", "EG", "OG"],
            positionen: [
                .heizkosten(heizInput),
                .wasser(wasserInput),
                .flaechenumlage(kostenart: "Grundsteuer", FlaechenInput(
                    basisBetragEuro: grundsteuer,
                    gesamtflaecheM2: 528,
                    flaechenProEinheit: ["KG": flaecheKG, "EG": flaecheEG, "OG": flaecheOG]
                )),
                .flaechenumlage(kostenart: "Versicherung", FlaechenInput(
                    basisBetragEuro: versicherung,
                    gesamtflaecheM2: 528,
                    flaechenProEinheit: ["KG": flaecheKG, "EG": flaecheEG, "OG": flaecheOG]
                ))
            ]
        )
        let e = AbrechnungsAggregator.aggregiere(input)

        // Jede Einheit: 5 Positionen (Heizung, Warmwasser, Wasser,
        // Grundsteuer, Versicherung).
        for id in ["KG", "EG", "OG"] {
            #expect(e.proEinheit[id]!.count == 5)
        }

        print("""

        ── Bahnhofstr. 37 Aggregat (4 Hauptkostenarten) ──
          Einheit    | Summe (Heiz+WW+Wasser+Grundsteuer+Versicherung)
        """)
        for id in ["KG", "EG", "OG"] {
            let summe = e.summe(fuer: id).gerundet(auf: 2, modus: .bankers)
            print("    \(id): \(summe) €")
        }
        print("""
          (OG-Excel-Ref Summe dieser 4 Blöcke:
              be_entwaesserung 342,16 + ww_heizung 1997,06 +
              grundsteuer 1188,54 + versicherung 749,11 = 4276,87 €
           Restliche 5 Positionen aus OG-Excel — Vorgartenpflege,
           Schnee-Eis, Allgemeinstrom, Reinigung, BSR — kommen in
           Task 0.22 End-to-End.)
        ──────────────────────────────────────────────────
        """)

        // Grundsteuer-Anteile gegen Erwartung
        let ogGrundsteuer = e.proEinheit["OG"]!.first { $0.kostenart == "Grundsteuer" }!
        #expect(ogGrundsteuer.mieteranteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "1188.54"))

        // Versicherung OG
        let ogVersicherung = e.proEinheit["OG"]!.first { $0.kostenart == "Versicherung" }!
        #expect(ogVersicherung.mieteranteilEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "749.11"))

        // Wasser OG innerhalb V1-Toleranz zur Ref 342,16 €
        let ogWasser = e.proEinheit["OG"]!.first { $0.kostenart == "Wasser (BWB)" }!
        let ogWasserAbweichung = (ogWasser.mieteranteilEuro - Decimal(string: "342.16")!).magnitude
        #expect(ogWasserAbweichung < 10)
    }
}
