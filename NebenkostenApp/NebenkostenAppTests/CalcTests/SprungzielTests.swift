//
//  SprungzielTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Verifiziert das `Sprungziel`-Enum + seine `uiRoute`-Ableitung.
//  Kein SwiftData nötig, reine Value-Type-Tests.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct SprungzielTests {

    @Test("einstellungenObjekt → Übersicht-Tab + Objekt-Section")
    func einstellungenObjekt_route() {
        let r = Sprungziel.einstellungenObjekt.uiRoute
        #expect(r.tab == .uebersicht)
        #expect(r.kontext == .oeffneEinstellungen(section: .objekt))
    }

    @Test("mieterVorauszahlung trägt einheitId durch bis zur Kontext-Payload")
    func mieterVorauszahlung_route() {
        let r = Sprungziel.mieterVorauszahlung(einheitId: "EG").uiRoute
        #expect(r.tab == .uebersicht)
        #expect(r.kontext == .oeffneEinstellungen(section: .mieter(einheitId: "EG")))
    }

    @Test("zaehlerstandErfassen → Zähler-Tab + Erfassen-Kontext")
    func zaehlerstand_route() {
        let id = UUID()
        let r = Sprungziel.zaehlerstandErfassen(zaehlerId: id).uiRoute
        #expect(r.tab == .zaehler)
        #expect(r.kontext == .erfasseZaehler(id: id))
    }

    @Test("rechnungKostenart → Rechnungen-Tab + Kostenart-Kontext")
    func rechnungKostenart_route() {
        let id = UUID()
        let r = Sprungziel.rechnungKostenart(kostenartId: id).uiRoute
        #expect(r.tab == .rechnungen)
        #expect(r.kontext == .oeffneKostenart(id: id))
    }

    @Test("einstellungenPeriode → Übersicht-Tab + Periode-Section")
    func einstellungenPeriode_route() {
        let r = Sprungziel.einstellungenPeriode.uiRoute
        #expect(r.tab == .uebersicht)
        #expect(r.kontext == .oeffneEinstellungen(section: .periode))
    }

    @Test("wmzPlausi → Zähler-Tab + Wärme-Medium-Fokus")
    func wmzPlausi_route() {
        let r = Sprungziel.wmzPlausi.uiRoute
        #expect(r.tab == .zaehler)
        #expect(r.kontext == .fokussiereMedium(roh: "waermeenergie"))
    }

    @Test("AppTabKey deckt alle 5 Tabs ab — keine Scheitel-Tabs")
    func tabKey_vollstaendig() {
        let alle = AppTabKey.allCases
        #expect(alle.count == 5)
        #expect(alle.contains(.uebersicht))
        #expect(alle.contains(.zaehler))
        #expect(alle.contains(.rechnungen))
        #expect(alle.contains(.belege))
        #expect(alle.contains(.abrechnungen))
    }
}
