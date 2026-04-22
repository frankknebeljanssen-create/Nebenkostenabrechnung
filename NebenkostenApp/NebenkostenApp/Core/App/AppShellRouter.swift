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

    /// Kontext fuer das Vorauszahlung-Eingabe-Sheet. `nil` = Sheet
    /// geschlossen. Identifiable-Wrapper, damit AppShell das Sheet
    /// ueber `.sheet(item:)` praesentieren kann. `einheitID` ist
    /// die Bezeichnung der Wohneinheit, die beim Oeffnen fokussiert
    /// werden soll (Scroll-Target); `nil` bedeutet „oeffne fuer
    /// alle Einheiten ohne Fokus".
    var vorauszahlungSheet: VorauszahlungSheetKontext?

    /// Kontext fuer das Zaehlerstand-Erfassen-Sheet. `nil` = Sheet
    /// geschlossen. Wird von Views geoeffnet, die das Sheet OHNE
    /// Tab-Wechsel zeigen wollen — z.B. die AbrechnungsKachel-
    /// Blocker-Tap-Flow. Ueber `springe(zu: .zaehlerstandErfassen)`
    /// landet man dagegen im Zaehler-Tab + Sheet dort (altes
    /// Verhalten, sinnvoll aus Home heraus).
    var zaehlerErfassenSheet: ZaehlerErfassenSheetKontext?

    /// Toggle fuer das Inspektor-Sheet („Was fehlt noch?"). Seit
    /// dem FAB-Rueckbau wird das Sheet ueber den „?"-Button im
    /// KontextHeader ausgeloest. Gebunden ist es in AppShell per
    /// `.sheet(isPresented:)`.
    var zeigeInspektor: Bool = false

    /// Toggle fuer das Einstellungen-Sheet. Der Zahnrad-Button
    /// lebt jetzt im KontextHeader (bottom-right), die Tab-
    /// spezifischen lokalen States sind damit obsolet. AppShell
    /// bindet seine `.sheet(isPresented:)` auf dieses Flag.
    var zeigeEinstellungen: Bool = false

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

    /// Oeffnet das VorauszahlungEingabeSheet mit optionalem Fokus
    /// auf eine bestimmte Einheit.
    func oeffneVorauszahlungSheet(einheitID: String? = nil) {
        vorauszahlungSheet = VorauszahlungSheetKontext(einheitID: einheitID)
    }

    /// Oeffnet das Zaehlerstand-Erfassen-Sheet direkt — ohne Tab-
    /// Wechsel. Nach Schliessen landet der User dort, wo er den
    /// Sprungziel-Tap ausgeloest hat (z.B. AbrechnungsKachel).
    func oeffneZaehlerErfassenSheet(zaehlerID: UUID) {
        zaehlerErfassenSheet = ZaehlerErfassenSheetKontext(zaehlerID: zaehlerID)
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

/// Identifiable-Wrapper fuer `AppShellRouter.vorauszahlungSheet`.
/// Der Sheet-Presenter (AppShell) bindet via `.sheet(item:)` und
/// baut das VorauszahlungEingabeSheet mit dem Fokus-Hinweis auf.
struct VorauszahlungSheetKontext: Identifiable, Hashable, Sendable {
    /// Bezeichnung (z.B. „OG") der Einheit, die beim Oeffnen des
    /// Sheets fokussiert werden soll. `nil` = kein Fokus, Sheet
    /// zeigt alle aktiven Mietverhaeltnisse.
    let einheitID: String?
    var id: String { einheitID ?? "_alle_" }
}

/// Identifiable-Wrapper fuer `AppShellRouter.zaehlerErfassenSheet`.
/// Traegt die Zaehler-UUID — der Sheet-Presenter (AppShell) schlaegt
/// den Zaehler im `@Query` nach und uebergibt ihn an `Zaehlerstand
/// ErfassenView`. So bleibt der Router SwiftData-frei.
struct ZaehlerErfassenSheetKontext: Identifiable, Hashable, Sendable {
    let zaehlerID: UUID
    var id: UUID { zaehlerID }
}
