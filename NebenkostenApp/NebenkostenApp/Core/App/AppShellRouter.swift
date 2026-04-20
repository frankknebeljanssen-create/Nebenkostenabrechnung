//
//  AppShellRouter.swift
//  NebenkostenApp — Core/App
//
//  Zentrale Navigations-Instanz für die App-Shell. Ersetzt den
//  bisherigen `@AppStorage("activeTab")`-Mechanismus in `AppShell`.
//  Zweck:
//    - Tab-State bleibt persistiert (selber UserDefaults-Key).
//    - `Sprungziel`s aus Anforderungs-Rows werden interpretiert
//      und in Tab-Wechsel + optionalen Aktions-Kontext übersetzt.
//    - Tab-Views beobachten `aktuellesSprungziel`, öffnen ihre
//      passende Reaktion (Erfassen-Sheet, CollapsibleSection,
//      Einstellungen-Section) und rufen dann `quittiere()`.
//
//  Der Router ist `@Observable` + `@MainActor` und wird in
//  `NebenkostenAppApp` als `@State` aufgebaut + via
//  `.environment(router)` an die View-Hierarchie gereicht.
//

import SwiftUI

@Observable
@MainActor
final class AppShellRouter {

    // MARK: - Persistierter Tab-State

    /// UserDefaults-Key — identisch zum bisherigen `@AppStorage
    /// ("activeTab")`, damit bestehende App-States nicht verloren
    /// gehen.
    static let storageKey = "activeTab"

    private let defaults: UserDefaults

    var aktiverTab: AppTab {
        didSet {
            if aktiverTab != oldValue {
                defaults.set(aktiverTab.rawValue, forKey: Self.storageKey)
            }
        }
    }

    // MARK: - Sprungziel-State

    /// Letztes ausgelöstes Sprungziel. Tab-Views beobachten dieses
    /// Feld via `.onChange(of: router.aktuellesSprungziel)` und
    /// führen die zum `UIRoute.Kontext` passende Aktion aus. Nach
    /// dem Verarbeiten rufen sie `quittiere()` auf, damit das Ziel
    /// nicht bei jedem Re-Render wieder feuert.
    var aktuellesSprungziel: Sprungziel?

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? AppTab.uebersicht.rawValue
        self.aktiverTab = AppTab(rawValue: raw) ?? .uebersicht
    }

    // MARK: - Navigation

    /// Springt zu einer Datenanforderung. Setzt `aktiverTab` auf
    /// den zugehörigen Tab und hinterlegt das Sprungziel, damit
    /// die Ziel-View eine feinere Aktion (Sheet, Section-Expansion)
    /// aufgreifen kann.
    func springe(zu ziel: Sprungziel) {
        let route = ziel.uiRoute
        aktiverTab = Self.map(tabKey: route.tab)
        aktuellesSprungziel = ziel
    }

    /// Wird von Tab-Views nach erfolgter Sprungziel-Reaktion
    /// aufgerufen — andernfalls würde der nächste Re-Render das
    /// Sheet erneut öffnen.
    func quittiere() {
        aktuellesSprungziel = nil
    }

    // MARK: - Mapping AppTabKey ↔ AppTab

    /// Übersetzt den Calc-Layer-`AppTabKey` in das UI-`AppTab`-
    /// Enum. Beide Enums halten die selben fünf Cases in gleicher
    /// Reihenfolge.
    static func map(tabKey: AppTabKey) -> AppTab {
        switch tabKey {
        case .uebersicht:   return .uebersicht
        case .zaehler:      return .zaehler
        case .rechnungen:   return .rechnungen
        case .belege:       return .belege
        case .abrechnungen: return .abrechnungen
        }
    }
}
