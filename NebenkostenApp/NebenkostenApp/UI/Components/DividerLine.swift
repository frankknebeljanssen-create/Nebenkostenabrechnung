//
//  DividerLine.swift
//  NebenkostenApp — UI/Components
//
//  0.5-pt-Trenner in DesignTokens.separator. Vertikale Variante
//  per Parameter.
//

import SwiftUI

struct DividerLine: View {
    var horizontal: Bool = true
    var farbe: Color = DesignTokens.separator

    var body: some View {
        if horizontal {
            Rectangle().fill(farbe).frame(height: 0.5)
        } else {
            Rectangle().fill(farbe).frame(width: 0.5)
        }
    }
}
