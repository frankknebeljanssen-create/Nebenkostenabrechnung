//
//  AppTab.swift
//  NebenkostenApp — UI/Shell
//
//  Fünf Haupt-Tabs der App-Shell (Product-Owner-Entscheidung Task
//  UI-0): Home, Zähler, Rechnungen, Belege, Abrechnung.
//  Einstellungen ist KEIN Tab — Zugang über Toolbar-Button rechts
//  oben in jedem Tab (AppShellChrome).
//
//  Der Enum-Case heisst weiterhin `.uebersicht` fuer
//  Backwards-Compat (persistierter `rawValue` in UserDefaults
//  bleibt identisch). Nur das User-sichtbare Label ist "Home".
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable, Codable {
    case uebersicht
    case zaehler
    case rechnungen
    case belege
    case abrechnungen

    var id: String { rawValue }

    /// TabBar-Label (max. 10 Zeichen, damit die Pill nicht reflowt).
    /// UI-Fix-2: "Abrechnung" statt "Abrechnungen" (11 Zeichen).
    var titel: String {
        switch self {
        case .uebersicht:   return "Home"
        case .zaehler:      return "Zähler"
        case .rechnungen:   return "Rechnungen"
        case .belege:       return "Belege"
        case .abrechnungen: return "Abrechnung"
        }
    }

    /// SF Symbol für den Tab-Item. UI-Fix-2: `function` (f(x)) war zu
    /// technisch — ersetzt durch `list.bullet.rectangle` (Abrechnungs-
    /// liste). Alle anderen bleiben.
    var sfSymbol: String {
        switch self {
        case .uebersicht:   return "house.fill"
        case .zaehler:      return "gauge.medium"
        case .rechnungen:   return "doc.text"
        case .belege:       return "doc"
        case .abrechnungen: return "list.bullet.rectangle"
        }
    }
}
