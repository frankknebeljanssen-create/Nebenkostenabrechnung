//
//  ZeitraumabgrenzungTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Testet beide Modi (zeitanteilig, rechnungsdatum).
//

import Foundation
import Testing
@testable import NebenkostenApp

struct ZeitraumabgrenzungTests {

    // MARK: - Helper

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        var komponenten = DateComponents()
        komponenten.year = jahr
        komponenten.month = monat
        komponenten.day = tag
        return kalender.date(from: komponenten)!
    }

    // MARK: - Zeitanteilig: Extremfälle

    @Test("Rechnung deckt Periode exakt → 100 % des Betrags")
    func deckungsgleich() {
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2024, 11, 1),
            rechnungBis: datum(2025, 10, 31),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 1_000
        )
        #expect(anteil == 1_000)
    }

    @Test("Rechnung komplett außerhalb der Periode → 0")
    func keineUeberlappung() {
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2023, 1, 1),
            rechnungBis: datum(2023, 12, 31),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 1_000
        )
        #expect(anteil == 0)
    }

    @Test("Rechnung komplett innerhalb der Periode → 100 %")
    func vollstaendigInnerhalb() {
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2025, 5, 1),
            rechnungBis: datum(2025, 5, 31),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 71.40
        )
        #expect(anteil.gerundet(auf: 2, modus: .bankers) == Decimal(string: "71.40"))
    }

    // MARK: - BSR 2025-Kalenderbescheid in NK 11/2024–10/2025

    @Test("BSR 2025 Jahresbescheid in NK-Periode 11/24–10/25 → 304/365 von 527,84 €")
    func bsr2025InNk() {
        // BSR-Rechnung: 01.01.2025 – 31.12.2025 (365 Tage)
        // NK-Periode:   01.11.2024 – 31.10.2025 (365 Tage)
        // Überlappung:  01.01.2025 – 31.10.2025 (304 Tage)
        // Anteil = 527,84 · 304/365 = 439,6257… → 439,63 (bankers auf 2)
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2025, 1, 1),
            rechnungBis: datum(2025, 12, 31),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: Decimal(string: "527.84")!
        )
        #expect(anteil.gerundet(auf: 2, modus: .bankers) == Decimal(string: "439.63"))
    }

    // MARK: - BSR 2024-Kalenderbescheid in NK 11/2024–10/2025

    @Test("Fiktiver BSR 2024 Jahresbescheid in NK 11/24–10/25 → 61/366 (Schaltjahr) von 500 €")
    func bsr2024SchaltjahrInNk() {
        // BSR-Rechnung: 01.01.2024 – 31.12.2024 (366 Tage, Schaltjahr)
        // NK-Periode:   01.11.2024 – 31.10.2025
        // Überlappung:  01.11.2024 – 31.12.2024 (61 Tage)
        // Anteil = 500 · 61/366 ≈ 83,33 €
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2024, 1, 1),
            rechnungBis: datum(2024, 12, 31),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 500
        )
        #expect(anteil.gerundet(auf: 2, modus: .bankers) == Decimal(string: "83.33"))
    }

    // MARK: - Randfälle

    @Test("Rechnung beginnt am letzten Tag der Periode → 1/N-Anteil")
    func beginntAmLetztenTag() {
        // Rechnung: 31.10.2025 – 09.11.2025 (10 Tage)
        // Periode:  01.11.2024 – 31.10.2025
        // Überlappung: 31.10.2025 (1 Tag)
        // Anteil = 1000 · 1/10 = 100
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2025, 10, 31),
            rechnungBis: datum(2025, 11, 9),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 1_000
        )
        #expect(anteil.gerundet(auf: 2, modus: .bankers) == 100)
    }

    @Test("Rechnungstage = 0 (identische Start-/End-Daten eines Tages) → anteil = Betrag wenn in Periode")
    func einTagesRechnung() {
        // Rechnung: 01.06.2025 – 01.06.2025 (1 Tag)
        // Periode:  01.11.2024 – 31.10.2025
        let anteil = Zeitraumabgrenzung.anteil(
            rechnungVon: datum(2025, 6, 1),
            rechnungBis: datum(2025, 6, 1),
            periodeVon:  datum(2024, 11, 1),
            periodeBis:  datum(2025, 10, 31),
            gesamtbetrag: 50
        )
        #expect(anteil == 50)
    }

    // MARK: - Rechnungsdatum-Modus (MVP)

    @Test("MVP: Leske-Rechnung vom 06.12.2024 voll in NK 2024/2025")
    func rechnungsdatumDrin() {
        let anteil = Zeitraumabgrenzung.anteilNachRechnungsdatum(
            rechnungsdatum: datum(2024, 12, 6),
            periodeVon:     datum(2024, 11, 1),
            periodeBis:     datum(2025, 10, 31),
            gesamtbetrag:   Decimal(string: "279.91")!
        )
        #expect(anteil == Decimal(string: "279.91")!)
    }

    @Test("MVP: Rechnungsdatum außerhalb der Periode → 0")
    func rechnungsdatumAusserhalb() {
        let anteil = Zeitraumabgrenzung.anteilNachRechnungsdatum(
            rechnungsdatum: datum(2025, 11, 15),
            periodeVon:     datum(2024, 11, 1),
            periodeBis:     datum(2025, 10, 31),
            gesamtbetrag:   200
        )
        #expect(anteil == 0)
    }

    @Test("MVP: Rechnungsdatum am ersten Tag der Periode → voll in Periode")
    func rechnungsdatumAmRand() {
        let anteil = Zeitraumabgrenzung.anteilNachRechnungsdatum(
            rechnungsdatum: datum(2024, 11, 1),
            periodeVon:     datum(2024, 11, 1),
            periodeBis:     datum(2025, 10, 31),
            gesamtbetrag:   100
        )
        #expect(anteil == 100)
    }
}
