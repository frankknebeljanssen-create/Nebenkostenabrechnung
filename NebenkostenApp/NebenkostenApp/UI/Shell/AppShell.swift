//
//  AppShell.swift
//  NebenkostenApp — UI/Shell
//
//  Root-Tab-View mit fünf Haupt-Tabs. Ersetzt die Phase-0-
//  RootTabView — diese bleibt als Debug-Zugriff über das
//  EinstellungenSheet (Task UI-0 C7) erreichbar.
//

import SwiftUI
import SwiftData

struct AppShell: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false

    private var aktiveTab: Binding<AppTab> {
        Binding(
            get: { router.aktiverTab },
            set: { router.aktiverTab = $0 }
        )
    }

    var body: some View {
        TabView(selection: aktiveTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tabContent(tab)
                        .background(DesignTokens.bgApp)
                }
                .tabItem { Label(tab.titel, systemImage: tab.sfSymbol) }
                .tag(tab)
            }
        }
        .background(DesignTokens.bgApp)
        // TabBar-Farben + Hintergrund kommen aus UITabBarAppearance
        // (NebenkostenAppApp.konfiguriereTabBar). Aber:
        // - `.toolbarBackground(.visible, for: .tabBar)` ist
        //   zwingend. Ohne diese Markierung schaltet iOS 26 die
        //   TabBar bei leeren oder kurz-scrollenden Tabs auf einen
        //   dunklen/transparenten Fallback, der dann als „schwarzer
        //   Block" durchschlaegt.
        // - `.tint(DesignTokens.accent)` wirkt nur auf Nicht-TabBar-
        //   Elemente (Buttons, NavLinks etc.); die TabBar-Pill bleibt
        //   durch UITabBarAppearance gesteuert.
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .tint(DesignTokens.accent)
        // UI-Fix-2 Fix 4b: Dynamic-Type-Cap auf TabBar, damit Labels
        // bei xxxLarge nicht abgeschnitten werden.
        .dynamicTypeSize(.large ... .xLarge)
        .sheet(isPresented: $zeigeScopePicker) {
            ScopePickerSheet()
        }
        .sheet(isPresented: inspektorBinding) {
            InspektorSheet()
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            EinstellungenSheet()
        }
        .sheet(item: vorauszahlungBinding) { kontext in
            if let immo = aktuelleImmobilie {
                VorauszahlungEingabeSheet(
                    immobilie: immo,
                    fokusEinheitID: kontext.einheitID
                )
            }
        }
    }

    /// Bindings-Adapter auf `router.vorauszahlungSheet` — damit
    /// `.sheet(item:)` beim User-Dismiss den Router-State auf
    /// nil setzt (sonst feuert das Sheet beim naechsten Re-Render
    /// erneut).
    private var vorauszahlungBinding: Binding<VorauszahlungSheetKontext?> {
        Binding(
            get: { router.vorauszahlungSheet },
            set: { router.vorauszahlungSheet = $0 }
        )
    }

    /// Binding auf `router.zeigeInspektor` fuer `.sheet(isPresented:)`.
    /// Der „?"-Button in AppShellChrome setzt `router.zeigeInspektor =
    /// true`, das Sheet hier reagiert.
    private var inspektorBinding: Binding<Bool> {
        Binding(
            get: { router.zeigeInspektor },
            set: { router.zeigeInspektor = $0 }
        )
    }

    private var aktuelleImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    // Die frühere `validateActiveTab()`-Absicherung wird durch
    // `AppShellRouter.init` selbst geleistet: ein unbekannter
    // rawValue fällt auf `.uebersicht` zurück. Daher hier nicht
    // mehr nötig.

    // MARK: - Tab-Content-Builder

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .uebersicht:   UebersichtView()
        case .zaehler:      ZaehlerView()
        case .rechnungen:   RechnungenView()
        case .belege:       BelegeView()
        case .abrechnungen: AbrechnungenView()
        }
        // Der AppShellChrome-Modifier wird von den einzelnen Tab-
        // Views selbst gesetzt — so können sie unterschiedliche
        // Titel/Subtitel-Texte liefern, aber teilen sich die Callbacks
        // durch die Umgebungs-Handler.
    }
}

