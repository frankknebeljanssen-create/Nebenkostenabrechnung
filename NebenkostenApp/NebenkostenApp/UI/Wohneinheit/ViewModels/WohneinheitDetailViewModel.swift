//
//  WohneinheitDetailViewModel.swift
//  NebenkostenApp — UI/Wohneinheit/ViewModels
//

import Foundation

@MainActor
struct WohneinheitDetailViewModel {
    let wohneinheit: Wohneinheit

    init(wohneinheit: Wohneinheit) {
        self.wohneinheit = wohneinheit
    }

    var gesamtflaecheImmobilie: Decimal {
        wohneinheit.immobilie?.gesamtflaecheM2 ?? 0
    }

    var aktiverMieter: Mietverhaeltnis? {
        (wohneinheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    /// Zähler der Einheit, sortiert nach Medium (Strom, Wasser kalt, warm,
    /// Wärmemengenzähler etc.) für eine stabile Reihenfolge auf der UI.
    var zaehler: [Zaehler] {
        (wohneinheit.zaehler ?? []).sorted { lhs, rhs in
            let rL = Self.mediumRang(lhs.medium)
            let rR = Self.mediumRang(rhs.medium)
            if rL != rR { return rL < rR }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    private static func mediumRang(_ medium: Medium) -> Int {
        switch medium {
        case .strom:         return 0
        case .kaltwasser:    return 1
        case .warmwasser:    return 2
        case .waermeenergie: return 3
        case .gas:           return 4
        case .oel:           return 5
        }
    }
}
