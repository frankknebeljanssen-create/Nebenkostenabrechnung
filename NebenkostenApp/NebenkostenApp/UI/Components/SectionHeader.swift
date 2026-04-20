//
//  SectionHeader.swift
//  NebenkostenApp — UI/Components
//
//  11 pt, 600, uppercase, tracking 0.6, in textTertiary. Mit optionalem
//  Trailing-Slot für einen Link ("Alle X prüfen →").
//

import SwiftUI

struct SectionHeader<Trailing: View>: View {
    let titel: String
    @ViewBuilder let trailing: () -> Trailing

    init(_ titel: String,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.titel = titel
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titel)
                .appFont(AppFont.smallCaptionSemi())
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.textTertiary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
