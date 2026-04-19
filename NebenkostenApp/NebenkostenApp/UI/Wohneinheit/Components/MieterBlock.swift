//
//  MieterBlock.swift
//  NebenkostenApp — UI/Wohneinheit/Components
//

import SwiftUI

struct MieterBlock: View {
    let mietverhaeltnis: Mietverhaeltnis?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mieter")
                .font(.headline)

            if let mv = mietverhaeltnis {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mv.mieterName.isEmpty ? "Mieter ohne Namen" : mv.mieterName)
                        .font(.body.weight(.semibold))

                    HStack(spacing: 8) {
                        Text(mv.mieterTyp.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())

                        if mv.anzahlPersonen > 1 {
                            Text("\(mv.anzahlPersonen) Personen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Kein aktives Mietverhältnis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Button { } label: { Text("Bearbeiten") }
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
