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

    @AppStorage("activeTab") private var aktiveTabRaw: String = AppTab.uebersicht.rawValue
    @State private var zeigeScopePicker = false
    @State private var zeigeInspektor = false
    @State private var zeigeEinstellungen = false

    private var aktiveTab: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: aktiveTabRaw) ?? .uebersicht },
            set: { aktiveTabRaw = $0.rawValue }
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
        .tint(DesignTokens.accent)
        .overlay(alignment: .bottomTrailing) {
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
