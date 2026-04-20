//
//  EinstellungenSheet.swift
//  NebenkostenApp — UI/Shell
//
//  Einstellungen-Sheet nach Design-Handoff. Nutzt das System-Form
//  für die Sections (DSGVO-Export, Datenlöschung, About), weil
//  diese Inhalte rein transaktional sind und vom System-Styling
//  profitieren (Hervorhebungsregeln, Swipe, Alert-Integration).
//  Ein Debug-Zugang zu den Phase-0-Views bleibt bis UI-3 als
//  letzte Section bestehen.
//
//  Top-Karte bringt das Design-System in das Sheet: App-Icon +
//  Versionsnummer, darunter die Scope-Info (aktueller Scope-Label
//  und ScopeFarbe).
//

import SwiftUI

struct EinstellungenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScopeManager.self) private var scope

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    kopfZeile
                }
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

                DatenExportSection()
                DatenLoeschungSection()
                AboutSection()

                Section {
                    NavigationLink("Altes Objekt-Dashboard") {
                        Phase0RootWrapper()
                    }
                    NavigationLink("Font-Probe (Plex)") {
                        FontProbeView()
                    }
                } header: {
                    Text("Debug · Phase-0-Views")
                } footer: {
                    Text("Debug-Menü wird nach Abschluss der UI-Umstellung (UI-1 … UI-3) entfernt.")
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

    // MARK: - Kopfzeile

    private var kopfZeile: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.accent)
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignTokens.accentText)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nebenkostenabrechnung")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(versionZeile)
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textSecondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(scope.farbe())
                        .frame(width: 6, height: 6)
                    Text(scope.beschriftung())
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            Spacer()
        }
    }

    private var versionZeile: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) · Build \(build)"
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
