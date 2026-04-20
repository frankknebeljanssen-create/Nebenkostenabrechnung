//
//  WmzPlausiTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für die WMZ-Plausi-Regel (85-115 %-Toleranz).
//  Baut einen minimalen In-Memory-Store mit Immobilie + Periode +
//  einem WMZ-Zähler + einer Gas-Rechnung, variiert die Werte.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct WmzPlausiTests {

    private struct Szenario {
        let container: ModelContainer
        let immobilie: Immobilie
        let periode: Abrechnungsperiode
        let kostenart: Kostenart
    }

    private func baueSzenario(
        gasVerbrauch: Decimal,
        wmzAnfang: Decimal,
        wmzEnde: Decimal,
        mitWmz: Bool = true
    ) throws -> Szenario {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext
        let immobilie = Immobilie()
        immobilie.adresse = "Teststr. 1"
        immobilie.gesamtflaecheM2 = 100
        ctx.insert(immobilie)

        // Einheit
        let einheit = Wohneinheit()
        einheit.bezeichnung = "EG"
        einheit.flaecheM2 = 100
        einheit.immobilie = immobilie
        ctx.insert(einheit)

        // Periode
        let kal = Calendar(identifier: .gregorian)
        let von = kal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let bis = kal.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let periode = Abrechnungsperiode()
        periode.von = von
        periode.bis = bis
        periode.immobilie = immobilie
        ctx.insert(periode)

        // Heiz-Kostenart + Rechnung mit verbrauchMenge
        let kostenart = Kostenart()
        kostenart.bezeichnung = "Heizung & Warmwasser"
        kostenart.immobilie = immobilie
        ctx.insert(kostenart)

        let rechnung = Rechnung()
        rechnung.lieferant = "GASAG"
        rechnung.rechnungsdatum = von
        rechnung.leistungVon = von
        rechnung.leistungBis = bis
        rechnung.betragBruttoEuro = 5000
        rechnung.verbrauchMenge = gasVerbrauch
        rechnung.kostenart = kostenart
        rechnung.immobilie = immobilie
        rechnung.validierungsStatus = .importiert
        ctx.insert(rechnung)

        // WMZ-Zähler + 2 Stände in der Periode
        if mitWmz {
            let zaehler = Zaehler()
            zaehler.medium = .waermeenergie
            zaehler.typ = .wohnung
            zaehler.bezeichnung = "WMZ EG"
            zaehler.einheit = "kWh"
            zaehler.wohneinheit = einheit
            ctx.insert(zaehler)

            let s1 = Zaehlerstand()
            s1.ablesedatum = von
            s1.stand = wmzAnfang
            s1.erfasstAm = von
            s1.zaehler = zaehler
            ctx.insert(s1)

            let s2 = Zaehlerstand()
            s2.ablesedatum = bis
            s2.stand = wmzEnde
            s2.erfasstAm = bis
            s2.zaehler = zaehler
            ctx.insert(s2)
        }

        try ctx.save()
        return Szenario(
            container: container,
            immobilie: immobilie,
            periode: periode,
            kostenart: kostenart
        )
    }

    @Test("Keine WMZ-Zähler → Regel nicht anwendbar (fehlt in Liste)")
    func keine_wmz_regel_fehlt() async throws {
        let s = try baueSzenario(
            gasVerbrauch: 10_000, wmzAnfang: 0, wmzEnde: 0, mitWmz: false
        )
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        #expect(!liste.contains { $0.anforderung.id == "plausi-wmz" })
    }

    @Test("WMZ in Toleranz (85-115%) → .erfuellt, schwere .warnung")
    func wmz_in_toleranz() async throws {
        // Erwartet = 10 000 × 0.82 = 8 200. WMZ-Delta = 8 000 → 97,6 %
        let s = try baueSzenario(
            gasVerbrauch: 10_000, wmzAnfang: 1_000, wmzEnde: 9_000
        )
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let plausi = liste.first { $0.anforderung.id == "plausi-wmz" }
        #expect(plausi?.status == .erfuellt)
        #expect(plausi?.schwere == .warnung)
        #expect(plausi?.sprungZiel == .wmzPlausi)
    }

    @Test("WMZ unter Toleranz (<85%) → .teilweise mit Hinweis, schwere .warnung")
    func wmz_unter_toleranz() async throws {
        // Erwartet = 10 000 × 0.82 = 8 200. Toleranz unten = 6 970.
        // WMZ-Delta = 4 000 → 48,8 % → unter 85 %.
        let s = try baueSzenario(
            gasVerbrauch: 10_000, wmzAnfang: 0, wmzEnde: 4_000
        )
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let plausi = liste.first { $0.anforderung.id == "plausi-wmz" }
        #expect(plausi?.status == .teilweise)
        #expect(plausi?.schwere == .warnung)
        #expect(plausi?.hinweis?.contains("49") == true)
    }

    @Test("WMZ über Toleranz (>115%) → .teilweise Hinweis")
    func wmz_ueber_toleranz() async throws {
        // Erwartet = 8 200. Toleranz oben = 9 430.
        // WMZ-Delta = 12 000 → 146 % → über 115 %.
        let s = try baueSzenario(
            gasVerbrauch: 10_000, wmzAnfang: 0, wmzEnde: 12_000
        )
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let plausi = liste.first { $0.anforderung.id == "plausi-wmz" }
        #expect(plausi?.status == .teilweise)
        #expect(plausi?.schwere == .warnung)
        #expect(plausi?.hinweis?.contains("146") == true)
    }

    @Test("WMZ-Warnung blockiert Berechnung NICHT (blockiertBerechnung == false)")
    func wmz_warnung_kein_blocker() async throws {
        let s = try baueSzenario(
            gasVerbrauch: 10_000, wmzAnfang: 0, wmzEnde: 500
        )
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let plausi = liste.first { $0.anforderung.id == "plausi-wmz" }!
        #expect(!plausi.blockiertBerechnung)
    }
}
