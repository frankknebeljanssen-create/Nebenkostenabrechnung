//
//  AppShell.swift
//  NebenkostenApp — UI/Shell
//
//  Root-Tab-View mit fünf Haupt-Tabs. Ersetzt die Phase-0-
//  RootTabView — diese bleibt als Debug-Zugriff über das
//  EinstellungenSheet (Task UI-0 C7) erreichbar.
//

import SwiftUI

struct AppShell: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router

    @State private var zeigeScopePicker = false
    @State private var zeigeInspektor = false
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
                }
                .tabItem { Label(tab.titel, systemImage: tab.sfSymbol) }
                .tag(tab)
            }
        }
        // UI-Fix-2 Fix 4c: aktives Tab-Icon kräftig (accentHover
        // statt accent), bessere Trennung vom bgAppCompact-Background.
        .tint(DesignTokens.accentHover)
        .toolbarBackground(DesignTokens.bgAppCompact, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        // UI-Fix-2 Fix 4b: Dynamic-Type-Cap auf TabBar, damit Labels
        // bei xxxLarge nicht abgeschnitten werden.
        .dynamicTypeSize(.large ... .xLarge)
        .overlay(alignment: .bottomTrailing) {
            // UI-Fix-2 Fix 4a: FAB sitzt in eigenem Overlay. TabBar-
            // Höhe + 12pt Abstand = 72pt bottom padding. Der ScrollView-
            // contentMargins-Anteil ist in den einzelnen Tab-Views
            // gesetzt (80pt bottom), damit der FAB keinen Content
            // verdeckt.
            InspektorFAB { zeigeInspektor = true }
                .padding(.trailing, 16)
                .padding(.bottom, 72)
        }
        .sheet(isPresented: $zeigeScopePicker) {
            ScopePickerSheet()
        }
        .sheet(isPresented: $zeigeInspektor) {
            InspektorPlatzhalter()
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            EinstellungenSheet()
        }
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

// MARK: - Floating Inspektor-Button

struct InspektorFAB: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(DesignTokens.accentText)
                .frame(width: 48, height: 48)
                .background(DesignTokens.accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("Was fehlt noch?")
    }
}
