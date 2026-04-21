//
//  ScopeManagerTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Persistenz und Bereinigungs-Logik des ScopeManagers. Nutzt isolierte
//  UserDefaults-Suites, damit die Tests nicht in die echte
//  User-Konfig schreiben.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct ScopeManagerTests {

    private func frischeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "ScopeManagerTests.\(name).\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)
        return ud
    }

    @Test("Initialer Scope ist .objekt, wenn keine Persistenz vorliegt")
    func default_ist_objekt() async throws {
        let ud = frischeDefaults("default")
        let sm = ScopeManager(defaults: ud)
        #expect(sm.isObjekt)
        #expect(sm.einheitID == nil)
    }

    @Test("Persistiert .einheit(\"OG\") und lädt sie nach Neustart")
    func persistenz_einheit() async throws {
        let ud = frischeDefaults("einheit")
        let sm1 = ScopeManager(defaults: ud)
        sm1.scope = .einheit(id: "OG")

        let sm2 = ScopeManager(defaults: ud)
        if case .einheit(let id) = sm2.scope {
            #expect(id == "OG")
        } else {
            Issue.record("Erwartet .einheit(\"OG\") nach Neustart, bekommen \(sm2.scope)")
        }
        #expect(sm2.einheitID == "OG")
    }

    @Test("Persistiert .objekt nach Wechsel zurück — überschreibt vorherige Einheit")
    func persistenz_objekt_ueberschreibt() async throws {
        let ud = frischeDefaults("zurueck")
        let sm1 = ScopeManager(defaults: ud)
        sm1.scope = .einheit(id: "EG")
        sm1.zuruecksetzenAufObjekt()

        let sm2 = ScopeManager(defaults: ud)
        #expect(sm2.isObjekt)
    }

    @Test("bereinige() setzt auf .objekt zurück, wenn die Einheit nicht mehr existiert")
    func bereinige_entfernt_ungueltige_einheit() async throws {
        let ud = frischeDefaults("bereinige_weg")
        let sm = ScopeManager(defaults: ud)
        sm.scope = .einheit(id: "DG")
        sm.bereinige(verfuegbareEinheitIDs: ["KG", "EG", "OG"])
        #expect(sm.isObjekt)
    }

    @Test("bereinige() lässt Scope unangetastet, wenn die Einheit vorhanden ist")
    func bereinige_laesst_gueltige_einheit() async throws {
        let ud = frischeDefaults("bereinige_ok")
        let sm = ScopeManager(defaults: ud)
        sm.scope = .einheit(id: "OG")
        sm.bereinige(verfuegbareEinheitIDs: ["KG", "EG", "OG"])
        #expect(sm.einheitID == "OG")
    }

    @Test("bereinige() tut nichts im Objekt-Scope, egal welche IDs")
    func bereinige_noop_im_objekt_scope() async throws {
        let ud = frischeDefaults("bereinige_objekt")
        let sm = ScopeManager(defaults: ud)
        sm.scope = .objekt
        sm.bereinige(verfuegbareEinheitIDs: [])
        #expect(sm.isObjekt)
    }

    @Test("Convenience: einheitID liefert nil im Objekt-Scope")
    func einheit_id_nil_im_objekt() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("id_nil"))
        sm.scope = .objekt
        #expect(sm.einheitID == nil)
    }

    // MARK: - Kontext-Header: Immobilie-ID

    @Test("aktuelleImmobilieID persistiert ueber ScopeManager-Neustart")
    func immobilie_persistiert() async throws {
        let ud = frischeDefaults("immo_persist")
        let a = UUID()
        let sm1 = ScopeManager(defaults: ud)
        sm1.aktuelleImmobilieID = a

        let sm2 = ScopeManager(defaults: ud)
        #expect(sm2.aktuelleImmobilieID == a)
    }

    @Test("aktuelleImmobilieID Wechsel (non-nil → non-nil) setzt Scope auf .objekt")
    func immobilie_wechsel_reset_scope() async throws {
        let ud = frischeDefaults("immo_wechsel")
        let a = UUID()
        let b = UUID()
        let sm = ScopeManager(defaults: ud)
        sm.aktuelleImmobilieID = a
        sm.scope = .einheit(id: "OG")

        sm.aktuelleImmobilieID = b
        #expect(sm.isObjekt)
        #expect(sm.aktuelleImmobilieID == b)
    }

    @Test("aktuelleImmobilieID Erst-Set (nil → non-nil) laesst Scope in Ruhe")
    func immobilie_erstset_kein_reset() async throws {
        let ud = frischeDefaults("immo_erstset")
        let sm = ScopeManager(defaults: ud)
        sm.scope = .einheit(id: "EG")
        sm.aktuelleImmobilieID = UUID()
        #expect(sm.einheitID == "EG")
    }

    @Test("bereinigeImmobilie setzt aktuelleImmobilieID auf nil, wenn verschwunden")
    func bereinige_immobilie() async throws {
        let ud = frischeDefaults("immo_bereinige")
        let a = UUID()
        let b = UUID()
        let sm = ScopeManager(defaults: ud)
        sm.aktuelleImmobilieID = a
        sm.bereinigeImmobilie(verfuegbareIDs: [b])
        #expect(sm.aktuelleImmobilieID == nil)
    }

    // MARK: - Kontext-Header: Perioden-ID

    @Test("aktuellePeriodeID wird pro Immobilie separat gemerkt")
    func periode_pro_immobilie() async throws {
        let ud = frischeDefaults("periode_pro")
        let immoA = UUID()
        let immoB = UUID()
        let periodeA = UUID()
        let periodeB = UUID()

        let sm = ScopeManager(defaults: ud)
        sm.aktuelleImmobilieID = immoA
        sm.aktuellePeriodeID = periodeA
        sm.aktuelleImmobilieID = immoB
        sm.aktuellePeriodeID = periodeB

        sm.aktuelleImmobilieID = immoA
        #expect(sm.aktuellePeriodeID == periodeA)
        sm.aktuelleImmobilieID = immoB
        #expect(sm.aktuellePeriodeID == periodeB)
    }

    @Test("aktuellePeriodeID ueberlebt ScopeManager-Neustart")
    func periode_persistiert() async throws {
        let ud = frischeDefaults("periode_persist")
        let immo = UUID()
        let periode = UUID()
        let sm1 = ScopeManager(defaults: ud)
        sm1.aktuelleImmobilieID = immo
        sm1.aktuellePeriodeID = periode

        let sm2 = ScopeManager(defaults: ud)
        #expect(sm2.aktuelleImmobilieID == immo)
        #expect(sm2.aktuellePeriodeID == periode)
    }

    @Test("aktuellePeriodeID ohne Immobilie ist nil und ignoriert Setter")
    func periode_ohne_immobilie() async throws {
        let ud = frischeDefaults("periode_nil")
        let sm = ScopeManager(defaults: ud)
        sm.aktuellePeriodeID = UUID()
        #expect(sm.aktuellePeriodeID == nil)
    }

    @Test("bereinigePeriode entfernt verschwundene Periode, behaelt gueltige")
    func bereinige_periode() async throws {
        let ud = frischeDefaults("periode_bereinige")
        let immo = UUID()
        let weg = UUID()
        let da  = UUID()

        let sm = ScopeManager(defaults: ud)
        sm.aktuelleImmobilieID = immo
        sm.aktuellePeriodeID = weg
        sm.bereinigePeriode(verfuegbareIDs: [da])
        #expect(sm.aktuellePeriodeID == nil)

        sm.aktuellePeriodeID = da
        sm.bereinigePeriode(verfuegbareIDs: [da])
        #expect(sm.aktuellePeriodeID == da)
    }

    @Test("bereinigeImmobilie raeumt Perioden-Merker verschwundener Objekte auf")
    func bereinige_raeumt_periodenwahl_auf() async throws {
        let ud = frischeDefaults("immo_periode_cleanup")
        let immoA = UUID()
        let immoB = UUID()
        let sm1 = ScopeManager(defaults: ud)
        sm1.aktuelleImmobilieID = immoA
        sm1.aktuellePeriodeID = UUID()
        sm1.aktuelleImmobilieID = immoB
        sm1.aktuellePeriodeID = UUID()

        sm1.bereinigeImmobilie(verfuegbareIDs: [immoB])

        // Nur immoB darf im Merker sein — Neustart sollte fuer immoA
        // nichts mehr finden.
        let sm2 = ScopeManager(defaults: ud)
        sm2.aktuelleImmobilieID = immoA
        #expect(sm2.aktuellePeriodeID == nil)
        sm2.aktuelleImmobilieID = immoB
        #expect(sm2.aktuellePeriodeID != nil)
    }
}
