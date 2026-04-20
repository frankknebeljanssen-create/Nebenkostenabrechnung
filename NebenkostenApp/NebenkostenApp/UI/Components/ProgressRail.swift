//
//  ProgressRail.swift
//  NebenkostenApp — UI/Components
//
//  4 pt hoher Fortschrittsbalken, radius 2, mit separator-Hintergrund
//  und vorgebener Fill-Farbe.
//

import SwiftUI

struct ProgressRail: View {
    /// 0…1
    let anteil: Double
    let fillFarbe: Color
    var hoehe: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.separator)
                Capsule()
                    .fill(fillFarbe)
                    .frame(width: proxy.size.width * max(0, min(1, anteil)))
            }
        }
        .frame(height: hoehe)
    }
}
