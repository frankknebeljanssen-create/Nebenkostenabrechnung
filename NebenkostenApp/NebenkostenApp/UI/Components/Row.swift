//
//  Row.swift
//  NebenkostenApp — UI/Components
//
//  Generische Card-Row mit links-Icon (optional), Label + optional
//  Subtitle, rechts-Content (ViewBuilder) und Chevron (optional).
//

import SwiftUI

struct Row<Leading: View, Trailing: View>: View {
    let label: String
    let subtitel: String?
    let chevron: Bool
    let action: (() -> Void)?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        label: String,
        subtitel: String? = nil,
        chevron: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.subtitel = subtitel
        self.chevron = chevron
        self.action = action
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        let inhalt = HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                if let subtitel {
                    Text(subtitel)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { inhalt }
                .buttonStyle(.plain)
        } else {
            inhalt
        }
    }
}
