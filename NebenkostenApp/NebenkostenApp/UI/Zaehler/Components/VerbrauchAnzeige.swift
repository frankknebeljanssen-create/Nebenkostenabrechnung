//
//  VerbrauchAnzeige.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Rechte Spalte einer Zähler-Row: "VERBRAUCH" + Wert + Einheit.
//  Nach meters-bills.jsx (Zeilen 97-121). Minimum-Breite 70pt,
//  rechtsbündig.
//

import SwiftUI

struct VerbrauchAnzeige: View {
    let verbrauch: Decimal?
    let einheit: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Verbrauch")
                .appFont(AppFont.messungLabel())
                .foregroundStyle(DesignTokens.textTertiary)
            Text(Formatting.verbrauch(verbrauch))
                .appFont(AppFont.monoBetrag17())
                .foregroundStyle(verbrauch != nil ? DesignTokens.text : DesignTokens.textTertiary)
                .lineLimit(1)
            if !einheit.isEmpty {
                Text(einheit)
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .frame(minWidth: 80, alignment: .trailing)
    }
}
