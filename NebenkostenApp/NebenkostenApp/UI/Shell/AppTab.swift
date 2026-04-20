//
//  AppTab.swift
//  NebenkostenApp — UI/Shell
//
//  Fünf Haupt-Tabs der App-Shell (Product-Owner-Entscheidung Task
//  UI-0): Übersicht, Zähler, Rechnungen, Belege, Abrechnungen.
//  Einstellungen ist KEIN Tab — Zugang über Toolbar-Button rechts
//  oben in jedem Tab (AppShellChrome).
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable, Codable {
    case uebersicht
    case zaehler
    case rechnungen
    case belege
    case abrechnungen

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .uebersicht:   return "Übersicht"
        case .zaehler:      return "Zähler"
        case .rechnungen:   return "Rechnungen"
        case .belege:       return "Belege"
        case .abrechnungen: return "Abrechnungen"
        }
    }

    var sfSymbol: String {
        switch self {
        case .uebersicht:   return "house.fill"
        case .zaehler:      return "gauge.medium"
        case .rechnungen:   return "doc.text"
        case .belege:       return "doc"
        case .abrechnungen: return "function"
        }
    }
}
