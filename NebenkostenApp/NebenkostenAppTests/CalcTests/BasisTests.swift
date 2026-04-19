//
//  BasisTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Verifiziert die Rundungs-Extension auf Decimal und den Default-Modus.
//

import Foundation
import Testing
@testable import NebenkostenApp

struct BasisTests {

    // MARK: - Kaufmännische Rundung

    @Test("Kaufmännisch: 5,5 rundet auf 6 (half away from zero)")
    func kaufmaennisch_halbAufwaerts() {
        let wert = Decimal(string: "5.5")!
        #expect(wert.gerundet(auf: 0, modus: .kaufmaennisch) == 6)
    }

    @Test("Kaufmännisch: 5,4 rundet auf 5 (halb abwärts)")
    func kaufmaennisch_halbAbwaerts() {
        let wert = Decimal(string: "5.4")!
        #expect(wert.gerundet(auf: 0, modus: .kaufmaennisch) == 5)
    }

    @Test("Kaufmännisch: 5,555 auf 2 Stellen ergibt 5,56")
    func kaufmaennisch_zweiStellen() {
        let wert = Decimal(string: "5.555")!
        #expect(wert.gerundet(auf: 2, modus: .kaufmaennisch) == Decimal(string: "5.56"))
    }

    @Test("Kaufmännisch negativ: −5,5 rundet auf −6")
    func kaufmaennisch_negativ() {
        let wert = Decimal(string: "-5.5")!
        #expect(wert.gerundet(auf: 0, modus: .kaufmaennisch) == -6)
    }

    // MARK: - Abrunden (Richtung Null)

    @Test("Abrunden: 5,99 auf 0 Stellen ergibt 5")
    func abrunden_ganzzahlig() {
        let wert = Decimal(string: "5.99")!
        #expect(wert.gerundet(auf: 0, modus: .abrunden) == 5)
    }

    @Test("Abrunden: 5,999 auf 1 Stelle ergibt 5,9")
    func abrunden_eineStelle() {
        let wert = Decimal(string: "5.999")!
        #expect(wert.gerundet(auf: 1, modus: .abrunden) == Decimal(string: "5.9"))
    }

    // MARK: - Aufrunden (weg von Null)

    @Test("Aufrunden: 5,01 auf 0 Stellen ergibt 6")
    func aufrunden_ganzzahlig() {
        let wert = Decimal(string: "5.01")!
        #expect(wert.gerundet(auf: 0, modus: .aufrunden) == 6)
    }

    @Test("Aufrunden: 5,001 auf 1 Stelle ergibt 5,1")
    func aufrunden_eineStelle() {
        let wert = Decimal(string: "5.001")!
        #expect(wert.gerundet(auf: 1, modus: .aufrunden) == Decimal(string: "5.1"))
    }

    // MARK: - Bankers-Rundung (half-to-even, Konvention für Positionsbeträge)

    @Test("Bankers: 2,5 rundet auf 2 (gerade)")
    func bankers_abwaerts() {
        let wert = Decimal(string: "2.5")!
        #expect(wert.gerundet(auf: 0, modus: .bankers) == 2)
    }

    @Test("Bankers: 3,5 rundet auf 4 (gerade)")
    func bankers_aufwaerts() {
        let wert = Decimal(string: "3.5")!
        #expect(wert.gerundet(auf: 0, modus: .bankers) == 4)
    }

    @Test("Bankers: 0,025 auf 2 Stellen ergibt 0,02 (gerade)")
    func bankers_zweiStellen() {
        let wert = Decimal(string: "0.025")!
        #expect(wert.gerundet(auf: 2, modus: .bankers) == Decimal(string: "0.02"))
    }

    // MARK: - Default-Modus

    @Test("Default-Modus ist kaufmännisch")
    func defaultModus() {
        let wert = Decimal(string: "5.5")!
        #expect(wert.gerundet(auf: 0) == wert.gerundet(auf: 0, modus: .kaufmaennisch))
    }

    // MARK: - Null-Wert

    @Test("Null-Wert bleibt in allen Modi 0")
    func nullWert() {
        let wert: Decimal = 0
        #expect(wert.gerundet(auf: 2, modus: .kaufmaennisch) == 0)
        #expect(wert.gerundet(auf: 2, modus: .abrunden) == 0)
        #expect(wert.gerundet(auf: 2, modus: .aufrunden) == 0)
    }

    // MARK: - Typealiases

    @Test("Typealiases sind identisch mit Decimal")
    func typealiasesSindDecimal() {
        let euro: Euro = Decimal(string: "12.34")!
        let flaeche: Flaeche = Decimal(string: "528")!
        let verbrauch: Verbrauch = Decimal(string: "32257")!
        #expect(euro == Decimal(string: "12.34"))
        #expect(flaeche == 528)
        #expect(verbrauch == 32_257)
    }

    // MARK: - AbrechnungsKontext

    @Test("AbrechnungsKontext ist Equatable und Sendable")
    func abrechnungsKontextGleichheit() {
        let start = Date(timeIntervalSince1970: 1_730_419_200) // 01.11.2024
        let ende  = Date(timeIntervalSince1970: 1_761_955_199) // 31.10.2025
        let a = AbrechnungsKontext(gesamtflaecheM2: 528, anzahlEinheiten: 3,
                                   periodeVon: start, periodeBis: ende)
        let b = AbrechnungsKontext(gesamtflaecheM2: 528, anzahlEinheiten: 3,
                                   periodeVon: start, periodeBis: ende)
        #expect(a == b)
    }
}
