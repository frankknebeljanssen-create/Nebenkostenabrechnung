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
}
