//
//  ZaehlerAnzeigeTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für die Zaehler.anzeigename / anzeigetyp / anzeigeort-
//  Computed-Properties. Nach UI-Fix-2 Fix 6 ist Pflicht, dass in
//  der UI niemals Roh-IDs oder Slugs erscheinen — alle User-
//  sichtbaren Texte kommen aus diesen Properties.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct ZaehlerAnzeigeTests {

    // MARK: - Test-Helpers

    private func mach(
        medium: Medium,
        typ: Zaehlertyp = .haupt,
        bezeichnung: String = "",
        einheit: String? = nil
    ) -> Zaehler {
        let z = Zaehler()
        z.medium = medium
        z.typ = typ
        z.bezeichnung = bezeichnung
        if let einheit {
            let e = Wohneinheit()
            e.bezeichnung = einheit
            z.wohneinheit = e
        }
        return z
    }

    // MARK: - anzeigename

    @Test("Gas-Hauptzähler bekommt 'Gas-Hauptzähler'")
    func gas_hauptzaehler() async throws {
        let z = mach(medium: .gas)
        #expect(z.anzeigename == "Gas-Hauptzähler")
    }

    @Test("Wasser-Hauptzähler (kaltwasser) bekommt 'Kaltwasser-Hauptzähler'")
    func wasser_hauptzaehler() async throws {
        let z = mach(medium: .kaltwasser)
        #expect(z.anzeigename == "Kaltwasser-Hauptzähler")
    }

    @Test("Wärme-Hauptzähler bekommt 'Wärme-Hauptzähler'")
    func waerme_hauptzaehler() async throws {
        let z = mach(medium: .waermeenergie)
        #expect(z.anzeigename == "Wärme-Hauptzähler")
    }

    @Test("Stromzähler OG bekommt 'Stromzähler OG'")
    func strom_og() async throws {
        let z = mach(medium: .strom, typ: .wohnung, einheit: "OG")
        #expect(z.anzeigename == "Stromzähler OG")
    }

    @Test("Stromzähler KG bekommt 'Stromzähler KG'")
    func strom_kg() async throws {
        let z = mach(medium: .strom, typ: .wohnung, einheit: "KG")
        #expect(z.anzeigename == "Stromzähler KG")
    }

    @Test("Kaltwasserzähler EG bekommt 'Kaltwasserzähler EG'")
    func kaltwasser_eg() async throws {
        let z = mach(medium: .kaltwasser, typ: .wohnung, einheit: "EG")
        #expect(z.anzeigename == "Kaltwasserzähler EG")
    }

    @Test("Warmwasserzähler OG bekommt 'Warmwasserzähler OG'")
    func warmwasser_og() async throws {
        let z = mach(medium: .warmwasser, typ: .wohnung, einheit: "OG")
        #expect(z.anzeigename == "Warmwasserzähler OG")
    }

    @Test("Wärmemengenzähler KG bekommt 'Wärmemengenzähler KG'")
    func waerme_kg() async throws {
        let z = mach(medium: .waermeenergie, typ: .wohnung, einheit: "KG")
        #expect(z.anzeigename == "Wärmemengenzähler KG")
    }

    @Test("Zwischenzähler Wasser mit Einheit → 'Gartenzähler EG'")
    func gartenzaehler_eg() async throws {
        let z = mach(medium: .kaltwasser, typ: .zwischen, einheit: "EG")
        #expect(z.anzeigename == "Gartenzähler EG")
    }

    @Test("Bezeichnung-Override hat Vorrang vor Auto-Namen")
    func override_bezeichnung() async throws {
        let z = mach(medium: .gas, bezeichnung: "Mein individueller Name")
        #expect(z.anzeigename == "Mein individueller Name")
    }

    @Test("Bezeichnung leer + nur Whitespace → Auto-Name")
    func override_whitespace_ignoriert() async throws {
        let z = mach(medium: .gas, bezeichnung: "   ")
        #expect(z.anzeigename == "Gas-Hauptzähler")
    }

    // MARK: - anzeigetyp

    @Test("anzeigetyp liefert Medium-Namen (Strom / Gas / Kaltwasser / Warmwasser / Wärmemenge / Öl)")
    func anzeigetyp_mapping() async throws {
        #expect(mach(medium: .strom).anzeigetyp == "Strom")
        #expect(mach(medium: .gas).anzeigetyp == "Gas")
        #expect(mach(medium: .kaltwasser).anzeigetyp == "Kaltwasser")
        #expect(mach(medium: .warmwasser).anzeigetyp == "Warmwasser")
        #expect(mach(medium: .waermeenergie).anzeigetyp == "Wärmemenge")
        #expect(mach(medium: .oel).anzeigetyp == "Öl")
    }

    // MARK: - anzeigeort

    @Test("anzeigeort: Einheit wenn Wohneinheit, leer sonst")
    func anzeigeort_standard() async throws {
        #expect(mach(medium: .strom, typ: .wohnung, einheit: "OG").anzeigeort == "OG")
        #expect(mach(medium: .gas).anzeigeort == "")
    }
}
