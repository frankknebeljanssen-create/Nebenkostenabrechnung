//
//  CloudKitSchemaSmokeTest.swift
//  NebenkostenAppTests — CalcTests
//
//  Task 0.21 Vorbereitung: Verifiziert die CloudKit-Grundvoraussetzungen
//  des @Model-Schemas, OHNE echten CloudKit-Container zu benötigen.
//
//  Was hier getestet wird:
//    - Alle @Model-Klassen haben parameterlose init() (CloudKit-Pflicht).
//    - Alle Properties haben Defaults oder sind Optional — d.h. ein
//      frisch instanziiertes Objekt kann ohne weitere Zuweisung
//      gespeichert und wieder geladen werden.
//    - Beziehungen sind optional und brechen nicht beim Persistieren.
//    - Das Schema kann fehlerfrei in einen lokalen ModelContainer
//      geladen werden (spiegelt den CloudKit-Init wider, ohne das
//      Entitlement-Tor).
//
//  Was hier NICHT getestet wird (erst nach Developer-Account-Aktivierung
//  und Capability-Setup möglich): der echte CloudKit-Sync zwischen
//  Geräten, Konflikt-Handling, Quota-Limits.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
struct CloudKitSchemaSmokeTest {

    @Test("Jede @Model-Klasse ist instanzierbar und persistierbar ohne Pflichtfelder")
    func alle_entitaeten_leer_persistierbar() throws {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext

        let appUser = AppUser()
        let immobilie = Immobilie()
        let wohneinheit = Wohneinheit()
        let mietverhaeltnis = Mietverhaeltnis()
        let zaehler = Zaehler()
        let zaehlerstand = Zaehlerstand()
        let kostenart = Kostenart()
        let rechnung = Rechnung()
        let periode = Abrechnungsperiode()
        let abrechnung = Abrechnung()
        let position = Abrechnungsposition()
        let audit = WarnungsAudit()

        for obj in [
            appUser as any PersistentModel, immobilie, wohneinheit, mietverhaeltnis,
            zaehler, zaehlerstand, kostenart, rechnung,
            periode, abrechnung, position, audit
        ] {
            ctx.insert(obj)
        }

        try ctx.save()

        // Zurücklesen jeder Entität — kein Fehler zu erwarten.
        #expect((try ctx.fetch(FetchDescriptor<AppUser>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Immobilie>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Wohneinheit>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Mietverhaeltnis>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Zaehler>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Zaehlerstand>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Kostenart>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Rechnung>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Abrechnungsperiode>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Abrechnung>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<Abrechnungsposition>())).count == 1)
        #expect((try ctx.fetch(FetchDescriptor<WarnungsAudit>())).count == 1)
    }

    @Test("Relationships bleiben nach Save/Load erhalten (Cascade-Pfade)")
    func relationships_erhalten() throws {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext

        let immobilie = Immobilie()
        immobilie.adresse = "Teststraße 1"
        immobilie.gesamtflaecheM2 = 100

        let wohneinheit = Wohneinheit()
        wohneinheit.bezeichnung = "EG"
        wohneinheit.flaecheM2 = 100
        wohneinheit.immobilie = immobilie

        let zaehler = Zaehler()
        zaehler.bezeichnung = "WMZ EG"
        zaehler.medium = .waermeenergie
        zaehler.wohneinheit = wohneinheit

        let stand = Zaehlerstand()
        stand.stand = 10_000
        stand.zaehler = zaehler

        let kostenart = Kostenart()
        kostenart.bezeichnung = "Testkosten"
        kostenart.immobilie = immobilie

        let rechnung = Rechnung()
        rechnung.lieferant = "Versorger X"
        rechnung.betragBruttoEuro = 100
        rechnung.immobilie = immobilie
        rechnung.kostenart = kostenart

        let periode = Abrechnungsperiode()
        periode.immobilie = immobilie

        ctx.insert(immobilie)
        ctx.insert(wohneinheit)
        ctx.insert(zaehler)
        ctx.insert(stand)
        ctx.insert(kostenart)
        ctx.insert(rechnung)
        ctx.insert(periode)
        try ctx.save()

        // Re-Fetch prüft, dass die Cascade-Pfade nach Persistierung
        // konsistent aufgelöst werden.
        let geladeneImmo = try ctx.fetch(FetchDescriptor<Immobilie>()).first!
        #expect(geladeneImmo.wohneinheiten?.count == 1)
        #expect(geladeneImmo.kostenarten?.count == 1)
        #expect(geladeneImmo.rechnungen?.count == 1)
        #expect(geladeneImmo.perioden?.count == 1)

        let ladenZaehler = geladeneImmo.wohneinheiten?.first?.zaehler?.first
        #expect(ladenZaehler?.staende?.count == 1)
    }

    @Test("String-Backing-Enums werden korrekt geroundtripped")
    func string_enums_roundtrip() throws {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext

        let user = AppUser()
        user.rolle = .unternehmer
        ctx.insert(user)

        let immo = Immobilie()
        immo.heizungsart = .fernwaerme
        immo.warmwasserbereitung = .elektroboiler
        ctx.insert(immo)

        let mv = Mietverhaeltnis()
        mv.mieterTyp = .gewerbemieter
        ctx.insert(mv)

        try ctx.save()

        let userNachFetch = try ctx.fetch(FetchDescriptor<AppUser>()).first!
        let immoNachFetch = try ctx.fetch(FetchDescriptor<Immobilie>()).first!
        let mvNachFetch = try ctx.fetch(FetchDescriptor<Mietverhaeltnis>()).first!

        #expect(userNachFetch.rolle == .unternehmer)
        #expect(immoNachFetch.heizungsart == .fernwaerme)
        #expect(immoNachFetch.warmwasserbereitung == .elektroboiler)
        #expect(mvNachFetch.mieterTyp == .gewerbemieter)
    }
}
