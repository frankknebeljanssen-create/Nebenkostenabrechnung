//
//  ScopeFarbe.swift
//  NebenkostenApp — UI/Components
//
//  Einheitliche Farb- und Icon-Zuordnung für den Scope-Indicator.
//  Liest Wohneinheit.farbkennungHex, fällt auf einen Geschoss-basierten
//  Default zurück.
//

import SwiftUI

enum ScopeFarbe {

    /// Farbe für eine Wohneinheit. Wenn `farbkennungHex` gesetzt, wird
    /// diese verwendet; sonst Default nach Geschoss-Rang.
    static func farbe(fuer einheit: Wohneinheit) -> Color {
        if let custom = ausHex(einheit.farbkennungHex) {
            return custom
        }
        return defaultFarbe(fuer: einheit.bezeichnung)
    }

    /// Icon passend zur Nutzungsart — Gewerbe bekommt Briefcase, Wohnung
    /// eine Person, Leerstand ein Gebäude-Icon.
    static func icon(fuer einheit: Wohneinheit) -> String {
        switch einheit.nutzungsart {
        case .gewerbe:          return "briefcase.fill"
        case .wohnung:          return "person.fill"
        case .einliegerwohnung: return "house.fill"
        case .leerstand:        return "building.2.fill"
        }
    }

    // MARK: - Default-Logik

    static func defaultFarbe(fuer bezeichnung: String) -> Color {
        switch rang(fuer: bezeichnung) {
        case 0:  return .purple    // KG / UG
        case 1:  return .blue      // EG
        case 2:  return .green     // OG / 1. OG
        case 3:  return .teal      // 2. OG
        case 4:  return .indigo    // DG
        default: return .orange
        }
    }

    private static func rang(fuer bezeichnung: String) -> Int {
        let key = bezeichnung.uppercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG", "KELLER", "KELLERGESCHOSS", "UNTERGESCHOSS": return 0
        case "EG", "ERDGESCHOSS":                                   return 1
        case "OG", "1. OG", "1.OG", "OBERGESCHOSS",
             "1. OBERGESCHOSS":                                     return 2
        case "2. OG", "2.OG", "2. OBERGESCHOSS":                    return 3
        case "DG", "DACHGESCHOSS":                                  return 4
        default:                                                    return 99
        }
    }

    // MARK: - Hex → Color

    /// "#RRGGBB" oder "RRGGBB" → Color. Nil bei ungültigem Input.
    private static func ausHex(_ hex: String) -> Color? {
        var rohe = hex.trimmingCharacters(in: .whitespaces)
        if rohe.hasPrefix("#") { rohe.removeFirst() }
        guard rohe.count == 6, let wert = UInt32(rohe, radix: 16) else {
            return nil
        }
        let r = Double((wert >> 16) & 0xFF) / 255.0
        let g = Double((wert >> 8) & 0xFF) / 255.0
        let b = Double(wert & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
