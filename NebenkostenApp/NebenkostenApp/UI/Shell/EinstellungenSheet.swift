//
//  EinstellungenSheet.swift
//  NebenkostenApp — UI/Shell
//
//  Platzhalter für das Einstellungen-Sheet. In UI-0 bietet es nur
//  den Debug-Zugriff auf die Phase-0-Views, damit die alten
//  Inhalte während der UI-Umstellung erreichbar bleiben.
//

import SwiftUI

struct EinstellungenSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Einstellungen-Oberfläche folgt in UI-1. Bis dahin sind die Phase-0-Screens unten erreichbar.")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                Section("Debug · Phase-0-Views") {
                    NavigationLink("Altes Objekt-Dashboard") {
                        Phase0RootWrapper()
                    }
                    NavigationLink("Font-Probe (Plex)") {
                        FontProbeView()
                    }
                }

                Section {
                    Text("Debug-Menü wird nach Abschluss der UI-Umstellung (UI-1 … UI-3) wieder entfernt.")
                        .appFont(AppFont.smallCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

/// Kapselt die Phase-0-`RootTabView` damit sie als NavigationLink-
/// Destination benutzbar bleibt. Wird zusammen mit dem Debug-Menü
/// in UI-3 entfernt.
private struct Phase0RootWrapper: View {
    var body: some View {
        RootTabView()
            .navigationTitle("Phase-0-App")
            .navigationBarTitleDisplayMode(.inline)
    }
}
