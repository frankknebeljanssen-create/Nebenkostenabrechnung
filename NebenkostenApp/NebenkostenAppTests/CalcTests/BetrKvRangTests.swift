//
//  BetrKvRangTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für die BetrKV-Reihenfolge im Rechnungen-Tab (UI-Fix-2).
//  Die neue Reihenfolge ist fix:
//    1 Heizung & Warmwasser · 2 Wasser · 3 Müll · 4 Grundsteuer
//    5 Versicherung · 6 Schornsteinfeger · 7 Reinigung/Garten
//    8 Hauswart · 9 Allgemeinstrom · 10 Reparatur · 99 ohne
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct BetrKvRangTests {

    @Test("Heizung und Warmwasser bekommen Rang 1")
    func heizung_warmwasser() async throws {
        #expect(RechnungenView.betrKvRang("Heizung") == 1)
        #expect(RechnungenView.betrKvRang("Warmwasser") == 1)
        #expect(RechnungenView.betrKvRang("Heizkosten") == 1)
    }

    @Test("Wasser (ohne Heiz/Warm) bekommt Rang 2")
    func wasser() async throws {
        #expect(RechnungenView.betrKvRang("Wasser") == 2)
        #expect(RechnungenView.betrKvRang("Entwässerung") == 2)
        #expect(RechnungenView.betrKvRang("Wasser & Entwässerung") == 2)
    }

    @Test("Müll bekommt Rang 3")
    func muell() async throws {
        #expect(RechnungenView.betrKvRang("Müllabfuhr") == 3)
        #expect(RechnungenView.betrKvRang("BSR") == 3)
        #expect(RechnungenView.betrKvRang("Stadtreinigung") == 3)
    }

    @Test("Grundsteuer Rang 4, Versicherung Rang 5, Schornsteinfeger Rang 6")
    func dritte_gruppe() async throws {
        #expect(RechnungenView.betrKvRang("Grundsteuer") == 4)
        #expect(RechnungenView.betrKvRang("Versicherung") == 5)
        #expect(RechnungenView.betrKvRang("Gebäudeversicherung") == 5)
        #expect(RechnungenView.betrKvRang("Schornsteinfeger") == 6)
    }

    @Test("Reinigung und Garten bekommen Rang 7")
    func reinigung_garten() async throws {
        #expect(RechnungenView.betrKvRang("Hausreinigung") == 7)
        #expect(RechnungenView.betrKvRang("Gartenpflege") == 7)
        #expect(RechnungenView.betrKvRang("Schneeräumen") == 7)
    }

    @Test("Hauswart Rang 8, Allgemeinstrom Rang 9")
    func hauswart_strom() async throws {
        #expect(RechnungenView.betrKvRang("Hauswart") == 8)
        #expect(RechnungenView.betrKvRang("Hausmeister") == 8)
        #expect(RechnungenView.betrKvRang("Allgemeinstrom") == 9)
        #expect(RechnungenView.betrKvRang("Strom") == 9)
    }

    @Test("Reparatur bekommt Rang 10")
    func reparatur() async throws {
        #expect(RechnungenView.betrKvRang("Reparatur") == 10)
        #expect(RechnungenView.betrKvRang("Instandhaltung") == 10)
    }

    @Test("Ohne Kostenart bekommt Rang 99")
    func ohne() async throws {
        #expect(RechnungenView.betrKvRang("ohne") == 99)
        #expect(RechnungenView.betrKvRang("") == 99)
    }

    @Test("Reihenfolge: Heizung < Wasser < Müll < Grundsteuer < Versicherung")
    func reihenfolge_monoton() async throws {
        let ränge = [
            RechnungenView.betrKvRang("Heizung"),
            RechnungenView.betrKvRang("Wasser"),
            RechnungenView.betrKvRang("Müllabfuhr"),
            RechnungenView.betrKvRang("Grundsteuer"),
            RechnungenView.betrKvRang("Versicherung"),
            RechnungenView.betrKvRang("Schornsteinfeger"),
            RechnungenView.betrKvRang("Hausreinigung"),
            RechnungenView.betrKvRang("Hauswart"),
            RechnungenView.betrKvRang("Allgemeinstrom"),
            RechnungenView.betrKvRang("Reparatur")
        ]
        for i in 1 ..< ränge.count {
            #expect(ränge[i] > ränge[i-1],
                    "Rang \(ränge[i]) sollte > \(ränge[i-1]) an Index \(i) sein")
        }
    }
}
