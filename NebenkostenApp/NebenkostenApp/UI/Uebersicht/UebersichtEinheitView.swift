//
//  UebersichtEinheitView.swift
//  NebenkostenApp — UI/Uebersicht
//
//  Einheit-Scope-Dashboard. Stub aus C2 — wird in C3 nach
//  `02-dashboard-einheit.jpg` mit echten Sections gefüllt.
//

import SwiftUI
import SwiftData

struct UebersichtEinheitView: View {
    let einheitId: String

    @Environment(ScopeManager.self) private var scope
    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Einheit-Scope · \(einheitId)")
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("Inhalt folgt in UI-1 C3.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(16)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Einheit-Übersicht",
            subtitel: einheitId,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
    }
}
