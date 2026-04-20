//
//  PlatzhalterInhalt.swift
//  NebenkostenApp — UI/Shell
//
//  Gemeinsamer Rumpf für die Placeholder-Tab-Views in UI-0. Zieht die
//  App-Shell (NavBar + ScopeStrip) an und zeigt einen neutralen
//  Hinweis, was in UI-1 ersetzt wird.
//

import SwiftUI
import SwiftData

struct PlatzhalterInhalt: View {
    let titel: String
    let subtitel: String?

    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "hammer")
                    .font(.largeTitle)
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Kommt in UI-1")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Platzhalter-Screen für »\(titel)«.")
                    .appFont(AppFont.body())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignTokens.separator)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(20)
            Spacer(minLength: 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: titel,
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
    }
}
