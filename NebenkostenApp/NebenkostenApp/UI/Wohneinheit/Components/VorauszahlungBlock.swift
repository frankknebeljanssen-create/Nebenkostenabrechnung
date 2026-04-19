//
//  VorauszahlungBlock.swift
//  NebenkostenApp — UI/Wohneinheit/Components
//

import SwiftUI

struct VorauszahlungBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vorauszahlungen")
                .font(.headline)
            Text("Noch keine Vorauszahlungen erfasst.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Button { } label: { Text("Vorauszahlung anlegen") }
                    .buttonStyle(.bordered)
                    .disabled(true)
                Text("Verfügbar in Task 0.15")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
