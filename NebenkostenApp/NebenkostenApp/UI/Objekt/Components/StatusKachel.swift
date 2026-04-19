//
//  StatusKachel.swift
//  NebenkostenApp — UI/Objekt/Components
//

import SwiftUI

enum KachelStatus: Equatable, Sendable {
    case gruen
    case gelb
    case rot

    var farbe: Color {
        switch self {
        case .gruen: return .green
        case .gelb:  return .orange
        case .rot:   return .red
        }
    }

    /// Gewicht für Aggregation zum Completion-Ring.
    var prozent: Double {
        switch self {
        case .gruen: return 1.0
        case .gelb:  return 0.5
        case .rot:   return 0.0
        }
    }
}

struct StatusKachel: View {
    let titel: String
    let symbol: String
    let status: KachelStatus
    let ist: Int
    let soll: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Circle()
                    .fill(status.farbe)
                    .frame(width: 12, height: 12)
                    .accessibilityLabel(accessibilityStatus)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(ist) / \(soll)")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var accessibilityStatus: String {
        switch status {
        case .gruen: return "vollständig"
        case .gelb:  return "teilweise"
        case .rot:   return "fehlt"
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        StatusKachel(titel: "Mieter",      symbol: "person.2",                 status: .gruen, ist: 3, soll: 3)
        StatusKachel(titel: "Zähler",      symbol: "gauge",                    status: .rot,   ist: 0, soll: 9)
        StatusKachel(titel: "Rechnungen",  symbol: "doc.text",                 status: .rot,   ist: 0, soll: 5)
        StatusKachel(titel: "Kostenarten", symbol: "list.bullet.rectangle",    status: .gelb,  ist: 2, soll: 5)
    }
    .padding()
}
