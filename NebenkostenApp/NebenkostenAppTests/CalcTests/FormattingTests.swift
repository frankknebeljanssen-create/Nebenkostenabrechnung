//
//  FormattingTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Mindestens 7 Tests auf Core/Design/Formatting.swift:
//  de_DE-Euro-Format (positiv / negativ / null / Tausendertrennung),
//  Datum, Periode mit EN-DASH, Prozent (ganz + dezimal).
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct FormattingTests {

    // MARK: - Euro

    @Test("Euro positiv: 4127.84 → '4.127,84 €' (ohne Tausenderpunkt-Fehler)")
    func euro_positiv_tausender() async throws {
        let s = Formatting.euro(Decimal(string: "4127.84")!)
        #expect(s == "4.127,84 €")
    }

    @Test("Euro null: 0 → '0,00 €'")
    func euro_null() async throws {
        #expect(Formatting.euro(0) == "0,00 €")
    }

    @Test("Euro negativ: −593.05 → '− 593,05 €' mit U+2212 MINUS-Dash")
    func euro_negativ() async throws {
        let s = Formatting.euro(Decimal(string: "-593.05")!)
        // U+2212 MINUS SIGN
        #expect(s == "\u{2212} 593,05 €")
        #expect(!s.contains("-"))   // kein ASCII-Hyphen
    }

    @Test("Euro positiv mit showSign: 4127.84 → '+ 4.127,84 €'")
    func euro_positiv_mit_vorzeichen() async throws {
        let s = Formatting.euro(Decimal(string: "4127.84")!, showSign: true)
        #expect(s == "+ 4.127,84 €")
    }

    // MARK: - Datum / Periode

    @Test("Datum: 18.01.2026 → 'dd.MM.yyyy'")
    func datum_format() async throws {
        var k = DateComponents()
        k.year = 2026; k.month = 1; k.day = 18
        let d = Calendar(identifier: .gregorian).date(from: k)!
        #expect(Formatting.datum(d) == "18.01.2026")
    }

    @Test("Periode mit en-dash: '01.01.2025 \u{2013} 31.12.2025'")
    func periode_en_dash() async throws {
        let von = datum(2025, 1, 1)
        let bis = datum(2025, 12, 31)
        let s = Formatting.periode(von, bis)
        #expect(s == "01.01.2025 \u{2013} 31.12.2025")
        // Kein Hyphen-Minus dazwischen
        #expect(!s.contains(" - "))
    }

    // MARK: - Prozent

    @Test("Prozent ganzzahlig: 0.85 → '85 %'")
    func prozent_ganz() async throws {
        #expect(Formatting.prozent(0.85, dezimal: 0) == "85 %")
    }

    @Test("Prozent mit Dezimal: 0.856 → '85,6 %'")
    func prozent_dezimal() async throws {
        #expect(Formatting.prozent(0.856, dezimal: 1) == "85,6 %")
    }

    @Test("Prozent 100: 1.0 → '100 %'")
    func prozent_voll() async throws {
        #expect(Formatting.prozent(1.0, dezimal: 0) == "100 %")
    }

    // MARK: - m² Fläche

    @Test("m² ganzzahlig: 79 → '79 m²' (keine 0er nachgestellt)")
    func m2_ganzzahlig() async throws {
        #expect(Formatting.m2(79) == "79 m²")
    }

    @Test("m² eine Nachkommastelle: 79,5 → '79,5 m²'")
    func m2_eine_dezimale() async throws {
        #expect(Formatting.m2(Decimal(string: "79.5")!) == "79,5 m²")
    }

    @Test("m² zwei Nachkommastellen: 79,45 → '79,45 m²'")
    func m2_zwei_dezimale() async throws {
        #expect(Formatting.m2(Decimal(string: "79.45")!) == "79,45 m²")
    }

    @Test("m² null: 0 → '0 m²'")
    func m2_null() async throws {
        #expect(Formatting.m2(0) == "0 m²")
    }

    @Test("m² mit Tausendern: 1234,5 → '1.234,5 m²'")
    func m2_tausender() async throws {
        #expect(Formatting.m2(Decimal(string: "1234.5")!) == "1.234,5 m²")
    }

    // MARK: - Helper

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var k = DateComponents()
        k.year = jahr; k.month = monat; k.day = tag
        return Calendar(identifier: .gregorian).date(from: k)!
    }
}
