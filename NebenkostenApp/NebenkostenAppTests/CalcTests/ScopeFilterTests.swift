//
//  ScopeFilterTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für ScopeFilter.sichtbareZaehler und .sichtbareAbrechnungen.
//  Setzt eine In-Memory-Immobilie via SwiftData auf, wie im
//  AbrechnungBahnhofstr37EndToEndTest.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct ScopeFilterTests {

    /// Baut einen frischen In-Memory-Container mit dem Bahnhofstr-
    /// Seed und gibt (Container, Immobilie) zurück. Der Container muss
    /// im Test-Scope gehalten werden, sonst deallokiert SwiftData den
    /// Model-Context und die Immobilie-Referenz wird ungültig.
    private struct SeedErgebnis {
        let container: ModelContainer
        let immobilie: Immobilie
    }

    private func seed() throws -> SeedErgebnis {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext
        SeedData.seedeWennLeer(in: ctx)
        try ctx.save()
        let immobilie = try ctx.fetch(FetchDescriptor<Immobilie>()).first!
        return SeedErgebnis(container: container, immobilie: immobilie)
    }

    // MARK: - Zähler

    @Test("Objekt-Scope: sichtbareZaehler enthält alle Haupt- + Einheit-Zähler")
    func zaehler_objekt_zeigt_alle() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let gesamt = (immobilie.hauptzaehler?.count ?? 0)
            + (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }.count
        let liste = ScopeFilter.sichtbareZaehler(immobilie: immobilie, scope: .objekt)
        #expect(liste.count == gesamt)
        #expect(liste.count >= 10) // Bahnhofstr hat 15 Zähler
    }

    @Test("Einheit-Scope OG: enthält OG-Zähler + Hauptzähler, keine EG/KG-Zähler")
    func zaehler_einheit_og_filtert() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let liste = ScopeFilter.sichtbareZaehler(
            immobilie: immobilie, scope: .einheit(id: "OG")
        )
        // Alle gelieferten Zähler sollten entweder Hauptzähler sein
        // oder zur OG-Einheit gehören.
        for z in liste {
            let istHaupt = z.immobilie != nil && z.wohneinheit == nil
            let istOg = z.wohneinheit?.bezeichnung == "OG"
            #expect(istHaupt || istOg,
                    "Zähler \(z.bezeichnung) gehört weder zum OG noch ist er Hauptzähler")
        }
        // Keine KG- oder EG-Einheit-Zähler
        #expect(!liste.contains { $0.wohneinheit?.bezeichnung == "KG" })
        #expect(!liste.contains { $0.wohneinheit?.bezeichnung == "EG" })
    }

    @Test("Einheit-Scope EG: mindestens ein Einheit-Zähler sichtbar")
    func zaehler_einheit_eg_hat_einheit_zaehler() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let liste = ScopeFilter.sichtbareZaehler(
            immobilie: immobilie, scope: .einheit(id: "EG")
        )
        let egEigene = liste.filter { $0.wohneinheit?.bezeichnung == "EG" }
        #expect(!egEigene.isEmpty, "EG-Scope muss mindestens einen EG-Zähler zeigen")
    }

    @Test("Einheit-Scope auf fehlende ID: nur Hauptzähler bleiben")
    func zaehler_einheit_nicht_vorhanden_nur_haupt() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let liste = ScopeFilter.sichtbareZaehler(
            immobilie: immobilie, scope: .einheit(id: "KEINE")
        )
        let haupt = immobilie.hauptzaehler ?? []
        #expect(liste.count == haupt.count)
    }

    // MARK: - Abrechnungen

    @Test("Objekt-Scope: sichtbareAbrechnungen gibt die volle Liste unverändert zurück")
    func abrechnungen_objekt_gibt_alle() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let perioden = immobilie.perioden ?? []
        let periode = perioden.sorted(by: { $0.von < $1.von }).first!
        let alle = try AbrechnungsService.aggregiere(periode: periode, immobilie: immobilie)
        let gefiltert = ScopeFilter.sichtbareAbrechnungen(alle: alle, scope: .objekt)
        #expect(gefiltert.count == alle.count)
        #expect(gefiltert == alle)
    }

    @Test("Einheit-Scope OG: sichtbareAbrechnungen enthält nur die OG-Abrechnung")
    func abrechnungen_einheit_og_nur_eine() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let perioden = immobilie.perioden ?? []
        let periode = perioden.sorted(by: { $0.von < $1.von }).first!
        let alle = try AbrechnungsService.aggregiere(periode: periode, immobilie: immobilie)
        let gefiltert = ScopeFilter.sichtbareAbrechnungen(
            alle: alle, scope: .einheit(id: "OG")
        )
        #expect(gefiltert.count == 1)
        #expect(gefiltert.first?.einheitBezeichnung == "OG")
    }

    @Test("Einheit-Scope auf nicht existierende ID: Liste ist leer")
    func abrechnungen_einheit_nicht_vorhanden_leer() async throws {
        let s = try seed(); let immobilie = s.immobilie
        let perioden = immobilie.perioden ?? []
        let periode = perioden.sorted(by: { $0.von < $1.von }).first!
        let alle = try AbrechnungsService.aggregiere(periode: periode, immobilie: immobilie)
        let gefiltert = ScopeFilter.sichtbareAbrechnungen(
            alle: alle, scope: .einheit(id: "ZZ")
        )
        #expect(gefiltert.isEmpty)
    }
}
