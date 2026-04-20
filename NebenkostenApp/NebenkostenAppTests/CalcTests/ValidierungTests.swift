//
//  ValidierungTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Alle 6 Cross-Entity-Checks plus Bahnhofstr-37-Realdaten.
//

import Foundation
import Testing
@testable import NebenkostenApp

struct ValidierungTests {

    // MARK: - Helfer

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents()
        c.year = jahr; c.month = monat; c.day = tag
        return k.date(from: c)!
    }

    private func minimalInput(
        einheiten: [ValidierungsInput.EinheitFlaeche] = [],
        gesamtflaeche: Decimal = 1_000,
        zaehlerstaende: [ValidierungsInput.Zaehlerstand] = [],
        rechnungen: [ValidierungsInput.Rechnung] = [],
        perioden: [ValidierungsInput.Periode] = [],
        aktuellePeriodeID: UUID? = nil,
        gasHauptzaehlerKwh: Decimal? = nil,
        wmzSummeKwh: Decimal = 0,
        wwWaermeKwh: Decimal = 0,
        umlageSumme: Decimal? = nil,
        rechnungGesamt: Decimal? = nil
    ) -> ValidierungsInput {
        ValidierungsInput(
            gesamtflaecheM2: gesamtflaeche,
            einheiten: einheiten,
            zaehlerstaende: zaehlerstaende,
            rechnungen: rechnungen,
            perioden: perioden,
            aktuellePeriodeID: aktuellePeriodeID,
            gasHauptzaehlerKwh: gasHauptzaehlerKwh,
            wmzSummeKwh: wmzSummeKwh,
            warmwasserWaermeKwh: wwWaermeKwh,
            umlageSummeEuro: umlageSumme,
            rechnungGesamtEuro: rechnungGesamt
        )
    }

    // MARK: - Check 1: Zählerstand-Rücklauf

    @Test("Check 1: Zwei Stände, zweiter kleiner als erster → Warnung")
    func check1_ruecklauf_erkannt() {
        let zID = UUID()
        let input = minimalInput(zaehlerstaende: [
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2024, 11, 1), wert: 100),
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2025, 10, 31), wert: 90)
        ])
        let w = Validierung.pruefe(input)
        let rueck = w.filter { $0.kategorie == "zaehlerstand_ruecklauf" }
        #expect(rueck.count == 1)
        #expect(rueck.first?.stufe == .warnung)
    }

    @Test("Check 1: Monoton steigende Stände → keine Warnung")
    func check1_monoton_ok() {
        let zID = UUID()
        let input = minimalInput(zaehlerstaende: [
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2024, 11, 1), wert: 100),
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2025, 10, 31), wert: 150)
        ])
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "zaehlerstand_ruecklauf" }.isEmpty)
    }

    // MARK: - Check 2: Rechnungs-Ausreißer

    @Test("Check 2: Neue Rechnung > 3× Durchschnitt → Warnung")
    func check2_ausreisser_erkannt() {
        let kaID = UUID()
        let input = minimalInput(rechnungen: [
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2022, 11, 1), betrag: 1_000, kostenartID: kaID, kostenartName: "Heizung"),
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2023, 11, 1), betrag: 1_100, kostenartID: kaID, kostenartName: "Heizung"),
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2024, 11, 1), betrag: 1_050, kostenartID: kaID, kostenartName: "Heizung"),
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2025, 11, 1), betrag: 4_000, kostenartID: kaID, kostenartName: "Heizung")
        ])
        let w = Validierung.pruefe(input)
        let a = w.filter { $0.kategorie == "rechnung_ausreisser" }
        #expect(a.count == 1)
        #expect(a.first?.stufe == .warnung)
    }

    @Test("Check 2: < 3 historische Rechnungen → keine Prüfung")
    func check2_zuWenigDaten() {
        let kaID = UUID()
        let input = minimalInput(rechnungen: [
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2024, 11, 1), betrag: 1_000, kostenartID: kaID, kostenartName: "Heizung"),
            .init(id: UUID(), lieferant: "GASAG", datum: datum(2025, 11, 1), betrag: 10_000, kostenartID: kaID, kostenartName: "Heizung")
        ])
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "rechnung_ausreisser" }.isEmpty)
    }

    // MARK: - Check 3: Perioden-Überschneidung

    @Test("Check 3: Aktuelle Periode überschneidet abgeschlossene → Fehler")
    func check3_ueberschneidung_erkannt() {
        let aktuelle = UUID(), abgeschlossen = UUID()
        let input = minimalInput(
            perioden: [
                .init(id: aktuelle, von: datum(2025, 6, 1), bis: datum(2026, 5, 31), abgeschlossen: false),
                .init(id: abgeschlossen, von: datum(2024, 11, 1), bis: datum(2025, 10, 31), abgeschlossen: true)
            ],
            aktuellePeriodeID: aktuelle
        )
        let w = Validierung.pruefe(input)
        let u = w.filter { $0.kategorie == "periode_ueberschneidung" }
        #expect(u.count == 1)
        #expect(u.first?.stufe == .fehler)
    }

    @Test("Check 3: Disjunkte Perioden → keine Warnung")
    func check3_disjunkt_ok() {
        let aktuelle = UUID(), abgeschlossen = UUID()
        let input = minimalInput(
            perioden: [
                .init(id: aktuelle, von: datum(2025, 11, 1), bis: datum(2026, 10, 31), abgeschlossen: false),
                .init(id: abgeschlossen, von: datum(2024, 11, 1), bis: datum(2025, 10, 31), abgeschlossen: true)
            ],
            aktuellePeriodeID: aktuelle
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "periode_ueberschneidung" }.isEmpty)
    }

    // MARK: - Check 4: Flächensumme

    @Test("Check 4: Σ Einheiten > Gesamtfläche → Fehler")
    func check4_flaechen_inkonsistent() {
        let input = minimalInput(
            einheiten: [
                .init(id: UUID(), bezeichnung: "KG", flaecheM2: 200),
                .init(id: UUID(), bezeichnung: "EG", flaecheM2: 200),
                .init(id: UUID(), bezeichnung: "OG", flaecheM2: 200)
            ],
            gesamtflaeche: 500
        )
        let w = Validierung.pruefe(input)
        let f = w.filter { $0.kategorie == "flaechen_inkonsistenz" }
        #expect(f.count == 1)
        #expect(f.first?.stufe == .fehler)
    }

    @Test("Check 4: Σ Einheiten = Gesamtfläche → keine Warnung")
    func check4_flaechen_exakt() {
        let input = minimalInput(
            einheiten: [
                .init(id: UUID(), bezeichnung: "KG", flaecheM2: 160),
                .init(id: UUID(), bezeichnung: "EG", flaecheM2: 181),
                .init(id: UUID(), bezeichnung: "OG", flaecheM2: 187)
            ],
            gesamtflaeche: 528
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "flaechen_inkonsistenz" }.isEmpty)
    }

    // MARK: - Check 5: WMZ vs. Hauptzähler

    @Test("Check 5: Abweichung 15 % > Toleranz 10 % → Hinweis")
    func check5_wmz_abweichung_gross() {
        // Gas 10 000, WW 1 000 → Heizung errechnet 9 000. WMZ-Summe 7 650 → 15 % Abweichung.
        let input = minimalInput(
            gasHauptzaehlerKwh: 10_000,
            wmzSummeKwh: 7_650,
            wwWaermeKwh: 1_000
        )
        let w = Validierung.pruefe(input)
        let h = w.filter { $0.kategorie == "wmz_vs_hauptzaehler" }
        #expect(h.count == 1)
        #expect(h.first?.stufe == .hinweis)   // physikalisch normal bis 10 %, darüber Hinweis
    }

    @Test("Check 5: Abweichung 5 % unter Toleranz → keine Warnung")
    func check5_wmz_kleineAbweichung() {
        let input = minimalInput(
            gasHauptzaehlerKwh: 10_000,
            wmzSummeKwh: 8_550,
            wwWaermeKwh: 1_000
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "wmz_vs_hauptzaehler" }.isEmpty)
    }

    // MARK: - Check 6: Umlage-Summe

    @Test("Check 6: Umlage-Summe weicht > 1 Cent ab → Warnung")
    func check6_umlage_abweichung() {
        let input = minimalInput(
            umlageSumme: Decimal(string: "3355.71")!,
            rechnungGesamt: Decimal(string: "3355.89")!
        )
        let w = Validierung.pruefe(input)
        let u = w.filter { $0.kategorie == "umlage_summe_abweichung" }
        #expect(u.count == 1)
        #expect(u.first?.stufe == .warnung)
    }

    @Test("Check 6: Umlage-Summe Cent-genau → keine Warnung")
    func check6_umlage_exakt() {
        let input = minimalInput(
            umlageSumme: Decimal(string: "3355.89")!,
            rechnungGesamt: Decimal(string: "3355.89")!
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "umlage_summe_abweichung" }.isEmpty)
    }

    // MARK: - Bahnhofstr. 37 — Realdaten aus JSON

    @Test("Bahnhofstr. 37: Σ Flächen 528 — Check 4 grün")
    func bahnhofstr_flaechen_grün() {
        let input = minimalInput(
            einheiten: [
                .init(id: UUID(), bezeichnung: "KG", flaecheM2: 160),
                .init(id: UUID(), bezeichnung: "EG", flaecheM2: 181),
                .init(id: UUID(), bezeichnung: "OG", flaecheM2: 187)
            ],
            gesamtflaeche: 528
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "flaechen_inkonsistenz" }.isEmpty)
    }

    @Test("Bahnhofstr. 37: WMZ-Summe 22 178 vs. Heizungs-Gasanteil 22 350,79 — Abweichung 0,77 %, Check 5 grün")
    func bahnhofstr_wmz_grün() {
        // Aus Testdaten-JSON v1.2:
        //   gasag.verbrauch_kwh = 32 257
        //   ww_gas_kwh         = 9 906,21
        //   wmz_total_kwh      = 22 178
        //   heizung_errechnet  = 32 257 − 9 906,21 = 22 350,79
        //   |22 350,79 − 22 178| = 172,79
        //   172,79 / 22 350,79 ≈ 0,77 %  < 10 % → grün
        let input = minimalInput(
            gasHauptzaehlerKwh: 32_257,
            wmzSummeKwh: 22_178,
            wwWaermeKwh: Decimal(string: "9906.21")!
        )
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "wmz_vs_hauptzaehler" }.isEmpty)
    }

    @Test("Bahnhofstr. 37: monotone Zählerstände aus JSON — Check 1 grün")
    func bahnhofstr_zaehler_grün() {
        // Beispiel wmz_kg: Anfang 16.422, Ende 24.741 MWh → monoton steigend
        let zID = UUID()
        let input = minimalInput(zaehlerstaende: [
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2024, 11, 1), wert: Decimal(string: "16.422")!),
            .init(zaehlerID: zID, zaehlerBezeichnung: "wmz_kg", datum: datum(2025, 10, 31), wert: Decimal(string: "24.741")!)
        ])
        let w = Validierung.pruefe(input)
        #expect(w.filter { $0.kategorie == "zaehlerstand_ruecklauf" }.isEmpty)
    }
}
