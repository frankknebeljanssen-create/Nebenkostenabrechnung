//
//  ScopeManagerDesignTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für die Design-Handoff-Erweiterungen des ScopeManagers:
//  `current`-Alias, Farb-Helper, Beschriftung. Die Persistenz-
//  Grundmechanik ist bereits in ScopeManagerTests abgedeckt.
//

import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct ScopeManagerDesignTests {

    private func frischeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "ScopeManagerDesignTests.\(name).\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)
        return ud
    }

    // MARK: - Alias

    @Test("current ist Alias auf scope — Setter und Getter")
    func current_alias_scope() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("alias"))
        #expect(sm.current == .objekt)
        #expect(sm.scope == .objekt)
        sm.current = .einheit(id: "OG")
        #expect(sm.scope == .einheit(id: "OG"))
        sm.scope = .objekt
        #expect(sm.current == .objekt)
    }

    @Test("AppScope und AbrechnungsScope sind identische Typen")
    func appscope_ist_abrechnungsscope() async throws {
        let a: AppScope = .einheit(id: "EG")
        let b: AbrechnungsScope = a
        #expect(a == b)
    }

    // MARK: - Persistenz über current

    @Test("Persistenz: current wird über UserDefaults überlebt")
    func persistenz_current() async throws {
        let ud = frischeDefaults("persist_current")
        let sm1 = ScopeManager(defaults: ud)
        sm1.current = .einheit(id: "KG")

        let sm2 = ScopeManager(defaults: ud)
        #expect(sm2.current == .einheit(id: "KG"))
    }

    // MARK: - Farb-Helper

    @Test("Objekt-Scope: farbe + softFarbe nutzen Tokens.unitObjekt*")
    func farbe_objekt() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("farbe_objekt"))
        sm.current = .objekt
        let f = sm.farbe([])
        let s = sm.softFarbe([])
        // Vergleich über RGB-Komponenten: bei gleichem Base-Hex und
        // unterschiedlichem Alpha müssen RGB identisch sein.
        #expect(gleicheRGB(f, DesignTokens.unitObjekt))
        #expect(gleicheRGB(s, DesignTokens.unitObjektSoft))
    }

    @Test("Einheit KG → DesignTokens.unitKG, Soft → unitKGSoft")
    func farbe_einheit_KG() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("farbe_kg"))
        sm.current = .einheit(id: "KG")
        #expect(gleicheRGB(sm.farbe([]), DesignTokens.unitKG))
        #expect(gleicheRGB(sm.softFarbe([]), DesignTokens.unitKGSoft))
    }

    @Test("Einheit OG → DesignTokens.unitOG (case-insensitive)")
    func farbe_einheit_OG_case_insensitiv() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("farbe_og"))
        sm.current = .einheit(id: "og")
        #expect(gleicheRGB(sm.farbe([]), DesignTokens.unitOG))
    }

    // MARK: - Beschriftung

    @Test("Objekt-Scope: beschriftung = 'Objekt · Gesamtes Haus'")
    func beschriftung_objekt() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("b_objekt"))
        sm.current = .objekt
        #expect(sm.beschriftung([]) == "Objekt · Gesamtes Haus")
    }

    @Test("Einheit ohne Mieter: beschriftung nutzt Nutzungsart-Label")
    func beschriftung_einheit_leerstand() async throws {
        let sm = ScopeManager(defaults: frischeDefaults("b_leer"))
        sm.current = .einheit(id: "DG")
        // Manuelle Wohneinheit ohne Mieter
        let e = Wohneinheit()
        e.bezeichnung = "DG"
        e.nutzungsart = .leerstand
        let text = sm.beschriftung([e])
        #expect(text.hasPrefix("Einheit · DG"))
        #expect(text.contains("Leerstand"))
    }
}

// MARK: - Hilfen

private func gleicheRGB(_ a: Color, _ b: Color) -> Bool {
    let rgbA = rgb(a)
    let rgbB = rgb(b)
    return rgbA.r == rgbB.r && rgbA.g == rgbB.g && rgbA.b == rgbB.b
}

private func rgb(_ color: Color) -> (r: Int, g: Int, b: Int) {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
}
