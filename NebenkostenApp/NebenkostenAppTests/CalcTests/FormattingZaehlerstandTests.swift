//
//  FormattingZaehlerstandTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für Formatting.zaehlerstand(_:einheit:) und .verbrauch(_:).
//  Regeln (UI-Fix-3):
//    - Wert < 10 → 3 Dezimalstellen
//    - Wert < 1.000 → 2 Dezimalstellen
//    - sonst → 0 Dezimalstellen
//    - Verbrauch < 10 → 1 Nachkommastelle, sonst 0
//    - nil → "— — —" bzw. "—"
//  de-DE-Locale (Komma Dezimal, Punkt Tausender).
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct FormattingZaehlerstandTests {

    // MARK: - zaehlerstand

    @Test("nil → '— — —'")
    func zaehlerstand_nil() async throws {
        #expect(Formatting.zaehlerstand(nil, einheit: "m³") == "— — —")
    }

    @Test("Kleiner Wert (<10) mit 3 Dezimalstellen")
    func zaehlerstand_klein() async throws {
        #expect(Formatting.zaehlerstand(Decimal(string: "7.5")!, einheit: "m³") == "7,500")
    }

    @Test("Mittlerer Wert (<1000) mit 2 Dezimalstellen")
    func zaehlerstand_mittel() async throws {
        #expect(Formatting.zaehlerstand(Decimal(string: "335.46")!, einheit: "m³") == "335,46")
    }

    @Test("Großer Wert mit 0 Dezimal + Tausenderpunkt")
    func zaehlerstand_gross() async throws {
        #expect(Formatting.zaehlerstand(Decimal(string: "382471")!, einheit: "kWh") == "382.471")
    }

    // MARK: - verbrauch

    @Test("Verbrauch nil → '—'")
    func verbrauch_nil() async throws {
        #expect(Formatting.verbrauch(nil) == "—")
    }

    @Test("Verbrauch klein (<10) → 1 Dezimalstelle")
    func verbrauch_klein() async throws {
        #expect(Formatting.verbrauch(Decimal(string: "4.2")!) == "4,2")
    }

    @Test("Verbrauch groß → 0 Dezimal + Tausenderpunkt")
    func verbrauch_gross() async throws {
        #expect(Formatting.verbrauch(Decimal(string: "29044")!) == "29.044")
    }

    @Test("Verbrauch exakt 10 → 0 Dezimal")
    func verbrauch_grenze() async throws {
        #expect(Formatting.verbrauch(Decimal(10)) == "10")
    }
}
