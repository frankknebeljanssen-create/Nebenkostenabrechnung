//
//  WarnCardEndstaende.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Orange Warn-Card oben in der ZählerView, sichtbar nur wenn
//  mindestens ein Zähler den Endstand der aktuellen Periode
//  fehlt. Nach meters-bills.jsx (Zeilen 25-43).
//

import SwiftUI

struct WarnCardEndstaende: View {
    let anzahl: Int
    let aktion: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DesignTokens.statusWarn)

            Text("\(anzahl) Endstand\(anzahl > 1 ? "e" : "") fehlt\(anzahl > 1 ? "en" : "")")
                .appFont(AppFont.bodySemi())
                .foregroundStyle(DesignTokens.statusWarn)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: aktion) {
                Text("Jetzt erfassen")
                    .appFont(AppFont.captionMedium())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignTokens.statusWarn)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DesignTokens.statusWarnSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignTokens.statusWarn.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
