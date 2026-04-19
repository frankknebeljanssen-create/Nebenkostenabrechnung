//
//  WasserkostenRechnerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Kombi-Preis-basierte Wasserkosten-Umlage (dynamisch abgeleitet).
//

import Foundation
import Testing
@testable import NebenkostenApp

struct WasserkostenRechnerTests {

    // MARK: - Gleichverteilung

    @Test("Drei Einheiten mit gleichem Verbrauch bekommen gleiche Anteile")
    func gleichverteilung() {
        let input = WasserkostenInput(
            bwbGesamtkostenEuro: 1500,
            verbrauchProEinheitM3: ["A": 100, "B": 100, "C": 100]
        )
        let e = WasserkostenRechner.berechne(input)

        #expect(e.summeEinzelverbrauchM3 == 300)
        #expect(e.kombiPreisEuroProM3 == 5)  // 1500 / 300

        for einheit in e.proEinheit {
            #expect(einheit.anteilEuro.gerundet(auf: 2, modus: .bankers) == 500)
        }
    }

    // MARK: - Asymmetrisch

    @Test("Asymmetrisch: Einheit mit doppeltem Verbrauch zahlt das Doppelte")
    func asymmetrisch() {
        let input = WasserkostenInput(
            bwbGesamtkostenEuro: 400,
            verbrauchProEinheitM3: ["A": 50, "B": 100]
        )
        let e = WasserkostenRechner.berechne(input)
        // Preis = 400 / 150 = 2,666…
        let a = e.proEinheit.first { $0.einheitID == "A" }!
        let b = e.proEinheit.first { $0.einheitID == "B" }!
        #expect(b.anteilEuro == a.anteilEuro * 2)
    }

    // MARK: - Summen-Erhaltung

    @Test("Σ Einheits-Anteile = bwb_gesamt (Cent-Level)")
    func summenErhaltung() {
        let input = WasserkostenInput(
            bwbGesamtkostenEuro: Decimal(string: "1427.83")!,
            verbrauchProEinheitM3: ["KG": Decimal(string: "5.25")!,
                                    "EG": Decimal(string: "320.95")!,
                                    "OG": Decimal(string: "104.54")!]
        )
        let e = WasserkostenRechner.berechne(input)

        let summe = e.proEinheit.reduce(Decimal(0)) { $0 + $1.anteilEuro }
        let abweichung = (summe - input.bwbGesamtkostenEuro).magnitude
        #expect(abweichung < Decimal(string: "0.000001")!)
    }

    // MARK: - Null-Summe Edge Case

    @Test("Σ = 0 → alle Anteile 0 € (keine Division-by-Zero)")
    func nullSumme() {
        let input = WasserkostenInput(
            bwbGesamtkostenEuro: 100,
            verbrauchProEinheitM3: ["A": 0, "B": 0]
        )
        let e = WasserkostenRechner.berechne(input)
        #expect(e.kombiPreisEuroProM3 == 0)
        for einheit in e.proEinheit {
            #expect(einheit.anteilEuro == 0)
        }
    }

    // MARK: - Bahnhofstr. 37 — BWB 2024/2025

    @Test("Bahnhofstr. 37 BWB 2024/2025 — Kombi-Preis-Verteilung")
    func bahnhofstr37_verteilung() throws {
        let daten = try Bahnhofstr37.laden()
        let bwb = daten.rechnung("bwb_2024_2025")
        let v = daten.zaehlerstaende.verbraeuche_berechnet

        // Einheit-Verbrauch = Kaltwasserzähler + Warmwasserzähler. Der
        // Gartenzwischenzähler ist ein Unterzähler in der EG-Leitung,
        // sein Verbrauch ist bereits in kw_eg_m3 enthalten — deshalb
        // NICHT nochmal addieren. Der Garten-Anteil fließt über kw_eg
        // in den EG-Verbrauch ein, EG trägt damit die Garten-Kosten.
        let kg = (v.kw_kg_m3 ?? 0) + (v.ww_kg_m3 ?? 0)    // 4,88 + 0,37  = 5,25
        let eg = (v.kw_eg_m3 ?? 0) + (v.ww_eg_m3 ?? 0)    // 281 + 39,95  = 320,95 (inkl. 192 Garten)
        let og = (v.kw_og_m3 ?? 0) + (v.ww_og_m3 ?? 0)    // 75,74 + 28,80 = 104,54

        let input = WasserkostenInput(
            bwbGesamtkostenEuro: bwb.gesamt_brutto,
            verbrauchProEinheitM3: ["KG": kg, "EG": eg, "OG": og]
        )
        let e = WasserkostenRechner.berechne(input)

        print("""

        ── Bahnhofstr. 37 BWB-Diagnostik (JSON v1.2, Kombi-Preis dynamisch) ──
          BWB-Gesamtkosten:          \(input.bwbGesamtkostenEuro) €
          Σ Einzelverbräuche:        \(e.summeEinzelverbrauchM3) m³
          Abgeleiteter Kombi-Preis:  \(e.kombiPreisEuroProM3.gerundet(auf: 4, modus: .bankers)) €/m³
                                     (eingetragener JSON-Wert 4,31 war rechnerisch nicht korrekt
                                      und steht jetzt auf null — siehe wasserpreis_anmerkung.)

          Pro Einheit (Verbrauch → Anteil):
        """)
        for einheit in e.proEinheit.sorted(by: { $0.einheitID < $1.einheitID }) {
            let a = einheit.anteilEuro.gerundet(auf: 2, modus: .bankers)
            print("    \(einheit.einheitID): \(einheit.verbrauchM3) m³  →  \(a) €")
        }
        print("""
          (Ref OG-Excel be_entwaesserung: 342,16 € — meine Rechnung ≈ 346,60 €,
           Δ ≈ 4,4 €. V1-Toleranz akzeptiert; Feinabgleich in Task 0.22.)
        ────────────────────────────────────────────────────────────────
        """)

        // Summen-Erhaltung auf Cent-Ebene:
        let summe = e.proEinheit.reduce(Decimal(0)) { $0 + $1.anteilEuro }
        let summeAbweichung = (summe - input.bwbGesamtkostenEuro).magnitude
        #expect(summeAbweichung < Decimal(string: "0.000001")!)

        // Abgeleiteter Preis sollte zwischen 3,30 und 3,33 €/m³ liegen
        // (Gesamt 1427,83 / Σ 430,74 ≈ 3,315 €/m³):
        #expect(e.kombiPreisEuroProM3.gerundet(auf: 4, modus: .bankers) == Decimal(string: "3.3148"))

        // OG-Anteil sollte in der Größenordnung der OG-Excel-Referenz
        // liegen (±10 €, V1-Toleranz):
        let ogEinheit = e.proEinheit.first { $0.einheitID == "OG" }!
        let ogAbweichung = (ogEinheit.anteilEuro - Decimal(string: "342.16")!).magnitude
        #expect(ogAbweichung < 10)
    }
}
