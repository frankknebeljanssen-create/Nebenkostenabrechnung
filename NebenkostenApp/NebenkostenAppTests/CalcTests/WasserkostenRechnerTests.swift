//
//  WasserkostenRechnerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Trinkwasser/Schmutzwasser-Verteilung inkl. Gartenzwischenzähler.
//

import Foundation
import Testing
@testable import NebenkostenApp

struct WasserkostenRechnerTests {

    // MARK: - Gleichverteilung ohne Garten

    @Test("Drei Einheiten mit gleichem Verbrauch bekommen gleiche Anteile")
    func gleichverteilungOhneGarten() {
        let input = WasserkostenInput(
            verbrauchGesamtM3: 300,
            trinkwasserKostenEuro: 600,
            schmutzwasserKostenEuro: 300,
            verbrauchProEinheitM3: ["A": 100, "B": 100, "C": 100]
        )
        let e = WasserkostenRechner.berechne(input)

        #expect(e.trinkwasserGesamtM3   == 300)
        #expect(e.schmutzwasserGesamtM3 == 300)
        #expect(e.gartenGesamtM3        == 0)

        for einheit in e.proEinheit {
            #expect(einheit.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers)    == 200)
            #expect(einheit.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers)  == 100)
            #expect(einheit.position.gesamtEuro.gerundet(auf: 2, modus: .bankers)          == 300)
        }
    }

    // MARK: - Gartenzwischenzähler reduziert nur Schmutzwasser

    @Test("Gartenzwischenzähler: Trinkwasser volle Menge, Schmutzwasser reduziert")
    func gartenzwischenzaehler() {
        let input = WasserkostenInput(
            verbrauchGesamtM3: 300,
            trinkwasserKostenEuro: 600,
            schmutzwasserKostenEuro: 270,  // 270 m³ schmutzwasserrelevant · 1 €/m³
            verbrauchProEinheitM3: ["A": 100, "B": 100, "C": 100],
            gartenM3ProEinheit: ["B": 30]   // B hat Garten 30 m³
        )
        let e = WasserkostenRechner.berechne(input)

        #expect(e.schmutzwasserGesamtM3 == 270)
        #expect(e.gartenGesamtM3        == 30)

        let a = e.proEinheit.first { $0.einheitID == "A" }!
        let b = e.proEinheit.first { $0.einheitID == "B" }!
        let c = e.proEinheit.first { $0.einheitID == "C" }!

        // Trinkwasser: jeder zahlt 200 € (100/300 seiner 600 €), auch B.
        #expect(a.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers) == 200)
        #expect(b.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers) == 200)
        #expect(c.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers) == 200)

        // Schmutzwasser: A und C je 100/270 von 270 € = 100 €, B 70/270 = 70 €.
        #expect(a.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == 100)
        #expect(b.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == 70)
        #expect(c.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == 100)

        // Abwasser-relevante m³ pro Einheit:
        #expect(a.schmutzwasserM3 == 100)
        #expect(b.schmutzwasserM3 == 70)
        #expect(c.schmutzwasserM3 == 100)
    }

    // MARK: - Summen-Erhaltung (Σ Einheit = Topf)

    @Test("Summe der Einheits-Positionen = Trinkwasser- und Schmutzwasser-Kosten")
    func summenErhaltung() {
        let input = WasserkostenInput(
            verbrauchGesamtM3: 434,
            trinkwasserKostenEuro: Decimal(string: "866.74")!,
            schmutzwasserKostenEuro: Decimal(string: "561.09")!,
            verbrauchProEinheitM3: ["KG": 18, "EG": 280, "OG": 136],
            gartenM3ProEinheit: ["EG": 191]
        )
        let e = WasserkostenRechner.berechne(input)

        let trinkwasserSumme = e.proEinheit.reduce(Decimal(0)) { $0 + $1.position.trinkwasserEuro }
        let schmutzwasserSumme = e.proEinheit.reduce(Decimal(0)) { $0 + $1.position.schmutzwasserEuro }

        #expect(trinkwasserSumme.gerundet(auf: 2, modus: .bankers)
             == input.trinkwasserKostenEuro.gerundet(auf: 2, modus: .bankers))
        #expect(schmutzwasserSumme.gerundet(auf: 2, modus: .bankers)
             == input.schmutzwasserKostenEuro.gerundet(auf: 2, modus: .bankers))
        #expect(e.schmutzwasserGesamtM3 == 243)
    }

    // MARK: - Einheit ohne Verbrauch bekommt 0

    @Test("Einheit mit 0 m³ Verbrauch bekommt keine Wasserkosten")
    func leereEinheit() {
        let input = WasserkostenInput(
            verbrauchGesamtM3: 100,
            trinkwasserKostenEuro: 200,
            schmutzwasserKostenEuro: 100,
            verbrauchProEinheitM3: ["A": 100, "B": 0]
        )
        let e = WasserkostenRechner.berechne(input)
        let b = e.proEinheit.first { $0.einheitID == "B" }!
        #expect(b.position.trinkwasserEuro   == 0)
        #expect(b.position.schmutzwasserEuro == 0)
        #expect(b.position.gesamtEuro        == 0)
    }

    // MARK: - Bahnhofstr. 37 — JSON v1.1 mit allen Kaltwasser-Anfangsständen

    @Test("Bahnhofstr. 37 BWB 2024/2025 — Verteilung inkl. Gartenzwischenzähler")
    func bahnhofstr37_verteilung() throws {
        let daten = try Bahnhofstr37.laden()
        let v = daten.zaehlerstaende.verbraeuche_berechnet
        let trinkwasserKosten   = daten.rechnungsposition("bwb_2024_2025", art: "Trinkwasser")
        let schmutzwasserKosten = daten.rechnungsposition("bwb_2024_2025", art: "Schmutzwasser")

        // Einheit-Verbrauch = Kaltwasserzähler + Warmwasserzähler (WW aus
        // demselben BWB-Hauptzähler gezogen).
        let kgVerbrauch = (v.kw_kg_m3 ?? 0) + (v.ww_kg_m3 ?? 0)   // 4,88 + 0,37 = 5,25
        let egVerbrauch = (v.kw_eg_m3 ?? 0) + (v.ww_eg_m3 ?? 0)   // 281 + 39,95 = 320,95 (inkl. 192 Garten)
        let ogVerbrauch = (v.kw_og_m3 ?? 0) + (v.ww_og_m3 ?? 0)   // 75,74 + 28,80 = 104,54

        let input = WasserkostenInput(
            verbrauchGesamtM3: 434,   // BWB-Hauptzähler (siehe bwb_2024_2025.positionen[0].menge_m3)
            trinkwasserKostenEuro: trinkwasserKosten,
            schmutzwasserKostenEuro: schmutzwasserKosten,
            verbrauchProEinheitM3: ["KG": kgVerbrauch, "EG": egVerbrauch, "OG": ogVerbrauch],
            gartenM3ProEinheit: ["EG": v.kw_eg_garten_m3 ?? 0]
        )
        let e = WasserkostenRechner.berechne(input)

        let summeEinheit = kgVerbrauch + egVerbrauch + ogVerbrauch
        let kombinierterPreis: Decimal = summeEinheit == 0 ? 0
            : (trinkwasserKosten + schmutzwasserKosten) / summeEinheit

        print("""

        ── Bahnhofstr. 37 BWB-Diagnostik (JSON v1.1) ──
          Trinkwasserkosten:         \(trinkwasserKosten) €
          Schmutzwasserkosten:       \(schmutzwasserKosten) €
          Σ Einheit-Verbrauch:       \(summeEinheit) m³ (Haupt 434 m³, Delta ≈ Leckage)
          Σ Schmutzwasser-relevant:  \(e.schmutzwasserGesamtM3) m³
          Kombi-Preis (1427,83/Σ):   \(kombinierterPreis.gerundet(auf: 4, modus: .bankers)) €/m³
                                     (JSON-Referenz 4,31 €/m³ — Herleitung offen)

          Pro Einheit (Trinkwasser / Schmutzwasser / Summe):
        """)

        for einheit in e.proEinheit {
            let tw = einheit.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers)
            let sw = einheit.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers)
            let gs = einheit.position.gesamtEuro.gerundet(auf: 2, modus: .bankers)
            print("    \(einheit.einheitID): \(tw) € / \(sw) € / \(gs) €")
        }
        print("""
          (OG-Excel-Referenz be_entwaesserung: 342,16 € — weicht von
           aktueller Formel ab; Ursache offen, siehe Status-Report.)
        ─────────────────────────────────────────────────
        """)

        // Konsistenz-Checks:
        //   Schmutzwasser-Basis-Reduktion: 434 − 192 = 242 (JSON-Hinweis nennt
        //   191 Garten-Abzug; v1.1 hat 192 aus Zählerstands-Differenz).
        #expect(e.schmutzwasserGesamtM3 == 242)

        // Formel-Verifikation auf Cent-Ebene gegen eigene Rechnung
        // (Trinkwasser: Kosten · einheitVerbrauch / 434;
        //  Schmutzwasser: Kosten · (einheitVerbrauch − Garten) / 242).
        let kg = e.proEinheit.first { $0.einheitID == "KG" }!
        let eg = e.proEinheit.first { $0.einheitID == "EG" }!
        let og = e.proEinheit.first { $0.einheitID == "OG" }!

        #expect(kg.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers)   == Decimal(string: "10.48"))
        #expect(kg.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "12.17"))
        #expect(eg.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers)   == Decimal(string: "640.97"))
        #expect(eg.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "298.98"))
        #expect(og.position.trinkwasserEuro.gerundet(auf: 2, modus: .bankers)   == Decimal(string: "208.78"))
        #expect(og.position.schmutzwasserEuro.gerundet(auf: 2, modus: .bankers) == Decimal(string: "242.38"))
    }
}
