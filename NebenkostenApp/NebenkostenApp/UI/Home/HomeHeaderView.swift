//
//  HomeHeaderView.swift
//  NebenkostenApp — UI/Home
//
//  Kleine Header-Zone oben im HomeScreen. Begrüßung + Perioden-
//  Info in zwei Zeilen, kein Hintergrund, bewusst ruhig.
//

import SwiftUI

struct HomeHeaderView: View {
    let immobilieBekannt: Bool
    let periodenLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gruss)
                .appFont(AppFont.Basis.displayTitle())
                .foregroundStyle(DesignTokens.text)
            if let periodenLabel {
                Text(periodenLabel)
                    .appFont(AppFont.Rechnungen.subZeile())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var gruss: String {
        immobilieBekannt ? "Willkommen zurück." : "Nebenkosten­abrechnung"
    }
}
