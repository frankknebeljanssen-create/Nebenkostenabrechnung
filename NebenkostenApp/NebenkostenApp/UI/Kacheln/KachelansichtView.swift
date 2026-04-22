//
//  KachelansichtView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Sekundaer-Navigation vom Home-Screen aus: 4 Kacheln in 2x2-Grid,
//  jede mit Kategorie-Completion (Stammdaten, Zaehler, Rechnungen,
//  Abrechnung). Vollstaendige Implementierung folgt im naechsten
//  Commit — dieser Stub haelt die NavigationLink-Destination fuer
//  den HomeView-Rebuild kompilierbereit.
//

import SwiftUI

struct KachelansichtView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Kachelansicht — folgt")
                .appFont(AppFont.bodySemi())
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Übersicht")
        .navigationBarTitleDisplayMode(.inline)
    }
}
