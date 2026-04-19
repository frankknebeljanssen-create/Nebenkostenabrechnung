//
//  HeizkostenRechnerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Formel-Verifikation (synthetische Werte) + Bahnhofstr.-37-Integration
//  gegen Testdaten/Bahnhofstr37_2025.json (Source of Truth).
//

import Foundation
import Testing
@testable import NebenkostenApp

struct HeizkostenRechnerTests {

    // MARK: - Formel-Sanity-Checks (pure Rechenbeispiele, keine Real-Daten)

    @Test("Formel: 10 % Flächen- und 10 % Verbrauchsquote → 10 % der Gesamtkosten")
    func formel_gleichgewichtig() {
        let input = HeizkostenInput(
            gesamtflaecheM2: 1_000,
            wohneinheitFlaecheM2: 100,
            wmzGesamt: 10_000,
            wmzWohneinheit: 1_000,
            gesamtkostenEuro: 1_000
        )
        let e = HeizkostenRechner.berechne(input)
        #expect(e.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers) == 30)
        #expect(e.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == 70)
        #expect(e.gesamtEuro.gerundet(auf: 2, modus: .bankers) == 100)
    }

    @Test("Formel: asymmetrisch — 5 % Fläche, 15 % Verbrauch, 1000 € Kosten")
    func formel_asymmetrisch() {
        let input = HeizkostenInput(
            gesamtflaecheM2: 1_000,
            wohneinheitFlaecheM2: 50,
            wmzGesamt: 10_000,
            wmzWohneinheit: 1_500,
            gesamtkostenEuro: 1_000
        )
        let e = HeizkostenRechner.berechne(input)
        // 0,30 · 0,05 · 1000 = 15,00  |  0,70 · 0,15 · 1000 = 105,00
        #expect(e.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers) == 15)
        #expect(e.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == 105)
        #expect(e.gesamtEuro.gerundet(auf: 2, modus: .bankers) == 120)
    }

    @Test("Formel: abweichender Flächenanteil 50 % (HeizkostenV-Maximum)")
    func formel_fuenfzigProzent() {
        let input = HeizkostenInput(
            gesamtflaecheM2: 1_000,
            wohneinheitFlaecheM2: 200,
            wmzGesamt: 10_000,
            wmzWohneinheit: 2_000,
            gesamtkostenEuro: 1_000,
            flaechenanteilProzent: 50
        )
        let e = HeizkostenRechner.berechne(input)
        #expect(e.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers) == 100)
        #expect(e.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers) == 100)
        #expect(e.gesamtEuro.gerundet(auf: 2, modus: .bankers) == 200)
    }

    @Test("Verteilerschlüssel-Text reflektiert Prozentsätze")
    func verteilerschluesselText() {
        let input = HeizkostenInput(
            gesamtflaecheM2: 100,
            wohneinheitFlaecheM2: 10,
            wmzGesamt: 100,
            wmzWohneinheit: 10,
            gesamtkostenEuro: 100
        )
        let e = HeizkostenRechner.berechne(input)
        #expect(e.verteilerschluesselText == "30 % Fläche + 70 % Verbrauch")
    }

    // MARK: - Bahnhofstr. 37 — Integration gegen JSON-Testdaten

    /// Baut einen HeizkostenInput aus den geladenen Testdaten für eine
    /// Einheit. Gibt nil zurück, wenn der WMZ-Verbrauch fehlt (z.B. EG).
    private func input(
        fuer einheitID: String,
        aus daten: Bahnhofstr37,
        wmzWohneinheit: Decimal
    ) -> HeizkostenInput {
        let einheit = daten.einheit(einheitID)
        let gasag = daten.rechnung("gasag_2024_2025")
        return HeizkostenInput(
            gesamtflaecheM2: daten.objekt.gesamtflaeche_qm,
            wohneinheitFlaecheM2: einheit.flaeche_qm,
            wmzGesamt: gasag.verbrauch_kwh!,
            wmzWohneinheit: wmzWohneinheit,
            gesamtkostenEuro: gasag.gesamt_brutto
        )
    }

    @Test("Bahnhofstr. 37 KG — WMZ 8319 kWh (Diagnostik der 0,47-€-Diskrepanz)")
    func bahnhofstr37_kg() throws {
        let daten = try Bahnhofstr37.laden()
        let wmzKg = daten.zaehlerstaende.verbraeuche_berechnet.wmz_kg_kwh!
        let input = input(fuer: "KG", aus: daten, wmzWohneinheit: wmzKg)
        let e = HeizkostenRechner.berechne(input)

        // Zwischenschritte loggen — zum Einordnen der CLAUDE.md-Referenz (652,27 €)
        // gegen unsere reine 30/70-Rechnung.
        let kosten = input.gesamtkostenEuro
        let grundkostenGesamt    = kosten * Decimal(string: "0.30")!
        let verbrauchskostenGesamt = kosten * Decimal(string: "0.70")!
        print("""

        ── KG Heizkosten-Diagnostik (Testdaten-JSON) ──
          Kosten (GASAG-Rechnung): \(kosten) €
          Grundkosten 30 %:        \(grundkostenGesamt.gerundet(auf: 2, modus: .bankers)) €
          Verbrauchskosten 70 %:   \(verbrauchskostenGesamt.gerundet(auf: 2, modus: .bankers)) €

          Fläche KG / gesamt:      \(input.wohneinheitFlaecheM2) / \(input.gesamtflaecheM2) m²
          WMZ  KG / gesamt:        \(input.wmzWohneinheit) / \(input.wmzGesamt) kWh

          → Flächenanteil   KG:    \(e.flaechenanteilEuro.gerundet(auf: 4, modus: .bankers)) €
          → Verbrauchsanteil KG:   \(e.verbrauchsanteilEuro.gerundet(auf: 4, modus: .bankers)) €
          → Gesamt           KG:   \(e.gesamtEuro.gerundet(auf: 2, modus: .bankers)) €

          (CLAUDE.md-Referenz mit wmzKg = 8450: 323,18 + 652,27 = 975,45 €)
        ────────────────────────────────────────────────
        """)

        // Konkrete Referenzwerte nach reiner 30/70-HeizkostenV-Rechnung,
        // gerundet auf 2 Nachkommastellen (Projekt-Konvention bankers):
        //   Flächenanteil   = 0,30 · 3554,95 · 160/528   = 323,18 €
        //   Verbrauchsanteil = 0,70 · 3554,95 · 8319/32257 = 641,77 €
        //   Gesamt                                        = 964,95 €
        //
        // Abweichung zur CLAUDE.md-Tabelle (323,18 / 652,27 / 975,45 mit wmz=8450):
        //   Δ Verbrauch ≈ +10,50 €, Δ Gesamt ≈ +10,50 €.
        #expect(e.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers)    == Decimal(string: "323.18"))
        #expect(e.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers)  == Decimal(string: "641.77"))
        #expect(e.gesamtEuro.gerundet(auf: 2, modus: .bankers)            == Decimal(string: "964.95"))
    }

    @Test("Bahnhofstr. 37 OG — WMZ 9499 kWh (sollte ohne Diskrepanz rechnen)")
    func bahnhofstr37_og() throws {
        let daten = try Bahnhofstr37.laden()
        let wmzOg = daten.zaehlerstaende.verbraeuche_berechnet.wmz_og_kwh!
        let input = input(fuer: "OG", aus: daten, wmzWohneinheit: wmzOg)
        let e = HeizkostenRechner.berechne(input)

        let kosten = input.gesamtkostenEuro
        let grundkostenGesamt    = kosten * Decimal(string: "0.30")!
        let verbrauchskostenGesamt = kosten * Decimal(string: "0.70")!
        print("""

        ── OG Heizkosten-Diagnostik (Testdaten-JSON) ──
          Fläche OG / gesamt:      \(input.wohneinheitFlaecheM2) / \(input.gesamtflaecheM2) m²
          WMZ  OG / gesamt:        \(input.wmzWohneinheit) / \(input.wmzGesamt) kWh

          → Flächenanteil   OG:    \(e.flaechenanteilEuro.gerundet(auf: 4, modus: .bankers)) €
          → Verbrauchsanteil OG:   \(e.verbrauchsanteilEuro.gerundet(auf: 4, modus: .bankers)) €
          → Gesamt           OG:   \(e.gesamtEuro.gerundet(auf: 2, modus: .bankers)) €
        ────────────────────────────────────────────────
        """)

        // Konkrete Referenzwerte nach reiner 30/70-HeizkostenV-Rechnung,
        // gerundet auf 2 Nachkommastellen:
        //   Flächenanteil   = 0,30 · 3554,95 · 187/528   = 377,71 €
        //   Verbrauchsanteil = 0,70 · 3554,95 · 9499/32257 = 732,80 €
        //   Gesamt                                        = 1110,51 €
        #expect(e.flaechenanteilEuro.gerundet(auf: 2, modus: .bankers)    == Decimal(string: "377.71"))
        #expect(e.verbrauchsanteilEuro.gerundet(auf: 2, modus: .bankers)  == Decimal(string: "732.80"))
        #expect(e.gesamtEuro.gerundet(auf: 2, modus: .bankers)            == Decimal(string: "1110.51"))
    }

    @Test(
        "Bahnhofstr. 37 EG — WMZ-Anfangsstand offen (blocked)",
        .disabled("Testdaten offene_fragen.wmz_eg_anfangsstand: Anfangsstand nicht dokumentiert.")
    )
    func bahnhofstr37_eg() throws {
        // Wird aktiviert, sobald wmz_eg_kwh in Testdaten-JSON belegt ist.
    }
}
