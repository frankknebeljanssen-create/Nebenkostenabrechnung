//
//  AppShellRouterTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für Core/App/AppShellRouter. Nutzt eine eigene
//  UserDefaults-Suite, damit die Runtime-Persistenz der App nicht
//  berührt wird.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct AppShellRouterTests {

    private func suite() -> UserDefaults {
        let suite = UserDefaults(suiteName: "AppShellRouterTests.\(UUID().uuidString)")!
        return suite
    }

    @Test("init ohne persistierten Wert landet auf .uebersicht")
    func init_default_uebersicht() {
        let router = AppShellRouter(defaults: suite())
        #expect(router.aktiverTab == .uebersicht)
        #expect(router.aktuellesSprungziel == nil)
    }

    @Test("init lädt persistierten Wert aus UserDefaults")
    func init_laedt_persistiert() {
        let d = suite()
        d.set("rechnungen", forKey: AppShellRouter.storageKey)
        let router = AppShellRouter(defaults: d)
        #expect(router.aktiverTab == .rechnungen)
    }

    @Test("unbekannter rawValue fällt auf .uebersicht zurück")
    func init_unbekannt_fallback() {
        let d = suite()
        d.set("nichtExistent", forKey: AppShellRouter.storageKey)
        let router = AppShellRouter(defaults: d)
        #expect(router.aktiverTab == .uebersicht)
    }

    @Test("set aktiverTab persistiert automatisch")
    func set_persistiert() {
        let d = suite()
        let router = AppShellRouter(defaults: d)
        router.aktiverTab = .belege
        #expect(d.string(forKey: AppShellRouter.storageKey) == "belege")
    }

    @Test("springe setzt Tab + Sprungziel in einem Aufruf")
    func springe_setzt_beides() {
        let router = AppShellRouter(defaults: suite())
        let id = UUID()
        router.springe(zu: .zaehlerstandErfassen(zaehlerId: id))
        #expect(router.aktiverTab == .zaehler)
        #expect(router.aktuellesSprungziel == .zaehlerstandErfassen(zaehlerId: id))
    }

    @Test("quittiere löscht Sprungziel, Tab bleibt")
    func quittiere_clear() {
        let router = AppShellRouter(defaults: suite())
        router.springe(zu: .einstellungenObjekt)
        #expect(router.aktuellesSprungziel != nil)
        router.quittiere()
        #expect(router.aktuellesSprungziel == nil)
        #expect(router.aktiverTab == .uebersicht)
    }

    @Test("AppTabKey → AppTab Mapping bleibt bijektiv")
    func mapping_bijektiv() {
        for key in AppTabKey.allCases {
            let tab = AppShellRouter.map(tabKey: key)
            #expect(tab.rawValue == key.rawValue)
        }
    }
}
