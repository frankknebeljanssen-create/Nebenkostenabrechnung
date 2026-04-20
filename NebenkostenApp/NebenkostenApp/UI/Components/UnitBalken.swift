//
//  UnitBalken.swift
//  NebenkostenApp — UI/Components
//
//  4 pt breiter vertikaler Farbbalken links an einer Card,
//  zeigt die Einheit-Farbe (Ocker / Grün / Blau / Slate) aus
//  DesignTokens bzw. ScopeManager.farbe.
//

import SwiftUI

struct UnitBalken: View {
    let farbe: Color
    var width: CGFloat = 4

    var body: some View {
        Rectangle()
            .fill(farbe)
            .frame(width: width)
            .cornerRadius(2)
    }
}
