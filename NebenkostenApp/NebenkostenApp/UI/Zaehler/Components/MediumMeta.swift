//
//  MediumMeta.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Präsentations-Metadaten pro Medium: Gruppen-Name, SF Symbol,
//  Accent-Farbe für den Section-Header-Icon. Farben übernommen
//  aus design_handoff meters-bills.jsx (mediumColors, Zeilen 16-19).
//

import SwiftUI

enum MediumMeta {

    /// Reihenfolge der Medium-Gruppen im Zähler-Screen.
    /// Entspricht design_handoff (Wärme zuerst, Gas am Ende).
    static let reihenfolge: [Medium] = [
        .waermeenergie, .warmwasser, .kaltwasser, .strom, .gas, .oel
    ]

    static func gruppenName(_ m: Medium) -> String {
        switch m {
        case .waermeenergie: return "Wärme"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .strom:         return "Allgemeinstrom"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }

    static func sfSymbol(_ m: Medium) -> String {
        switch m {
        case .waermeenergie: return "flame"
        case .gas:           return "flame"
        case .warmwasser:    return "drop.fill"
        case .kaltwasser:    return "drop"
        case .strom:         return "bolt"
        case .oel:           return "drop.triangle.fill"
        }
    }

    static func farbe(_ m: Medium) -> Color {
        switch m {
        case .waermeenergie: return Color(hex: "#C2610F")
        case .warmwasser:    return Color(hex: "#8C5A3C")
        case .kaltwasser:    return Color(hex: "#3A6B8C")
        case .strom:         return Color(hex: "#B8841F")
        case .gas:           return Color(hex: "#B8841F")
        case .oel:           return Color(hex: "#C2610F")
        }
    }
}
