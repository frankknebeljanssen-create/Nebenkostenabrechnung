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

    // MARK: - Bahnhofstr. 37 — blockiert bis Kaltwasser-Anfangsstände geklärt

    @Test(
        "Bahnhofstr. 37 (blocked: Kaltwasser-Anfangsstände fehlen)",
        .disabled("Testdaten-JSON enthält nur Endstände der Kaltwasserzähler kw_kg/kw_eg/kw_og — ohne Anfangsstände kein Periodenverbrauch pro Einheit.")
    )
    func bahnhofstr37_verteilung() throws {
        // Aktivieren, sobald Kaltwasser-Anfangsstände (01.11.2024) in
        // Testdaten/Bahnhofstr37_2025.json nachgetragen sind.
    }
}
