//
//  MediumSection.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Gruppen-Section im Zähler-Screen. Header: Medium-Icon +
//  uppercase Medium-Name + Anzahl. Inhalt: Card mit MeterRows,
//  0.5pt separator-Divider zwischen den Rows. Nach meters-bills.jsx
//  (Zeilen 45-70).
//

import SwiftUI

struct MediumSection: View {
    let medium: Medium
    let zaehler: [Zaehler]
    let periode: Abrechnungsperiode?
    let onTapZaehler: (Zaehler) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            card
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: MediumMeta.sfSymbol(medium))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MediumMeta.farbe(medium))
            Text(MediumMeta.gruppenName(medium))
                .appFont(AppFont.uppercaseLabel())
                .foregroundStyle(DesignTokens.textTertiary)
            Text("\(zaehler.count)")
                .appFont(AppFont.monoSmall())
                .foregroundStyle(DesignTokens.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(zaehler.enumerated()), id: \.element.id) { idx, z in
                Button {
                    onTapZaehler(z)
                } label: {
                    MeterRow(zaehler: z, periode: periode)
                }
                .buttonStyle(.plain)
                if idx < zaehler.count - 1 {
                    DividerLine()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
