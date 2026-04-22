//
//  PaginationDots.swift
//  NebenkostenApp — UI/Components
//
//  Reihe aus kleinen Kreisen fuer horizontale Paging-Container.
//  Aktiver Dot in Accent-Farbe (9 pt), inaktive dezent (7 pt).
//  Leicht animierter Uebergang macht den Scroll-Status lesbar,
//  ohne den Blick vom eigentlichen Inhalt zu ziehen.
//
//  Aktuell genutzt von `WohneinheitCarousel` auf dem Home-Screen.
//  Kein Padding links/rechts — Parent zentriert.
//

import SwiftUI

struct PaginationDots: View {
    let anzahl: Int
    let aktiv: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< anzahl, id: \.self) { i in
                Circle()
                    .fill(farbe(fuer: i))
                    .frame(width: i == aktiv ? 9 : 7, height: i == aktiv ? 9 : 7)
                    .animation(.easeOut(duration: 0.15), value: aktiv)
            }
        }
        .padding(.top, 2)
    }

    private func farbe(fuer i: Int) -> Color {
        i == aktiv
            ? DesignTokens.accent
            : DesignTokens.textTertiary.opacity(0.35)
    }
}
