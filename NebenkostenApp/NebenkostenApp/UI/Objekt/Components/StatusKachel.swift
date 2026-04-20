//
//  StatusKachel.swift
//  NebenkostenApp — UI/Objekt/Components
//
//  Kachel im Dashboard-Grid. Zeigt pro Domäne (Mieter, Zähler,
//  Rechnungen, Kostenarten) die Zahl erledigter/offener Punkte — kein
//  verwirrendes "7 / 5" mehr, sondern klar "erledigt" und "offen".
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
    /// Klar erledigte Punkte.
    let erledigt: Int
    /// In Arbeit / teilweise erfüllt (Plausi-Warnung, Lohnanteil fehlt etc.).
    let inArbeit: Int
    /// Noch komplett offen.
    let offen: Int

    init(titel: String, symbol: String, status: KachelStatus,
         erledigt: Int, inArbeit: Int = 0, offen: Int = 0) {
        self.titel = titel
        self.symbol = symbol
        self.status = status
        self.erledigt = erledigt
        self.inArbeit = inArbeit
        self.offen = offen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                statusText
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusText: some View {
        if offen == 0 && inArbeit == 0 {
            // Alles erledigt — prominent grün.
            Text("\(erledigt) erledigt")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(erledigt) erledigt")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    if inArbeit > 0 {
                        Text("\(inArbeit) in Arbeit")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if inArbeit > 0 && offen > 0 {
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                    }
                    if offen > 0 {
                        Text("\(offen) offen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
        StatusKachel(titel: "Mieter",      symbol: "person.2",              status: .gruen, erledigt: 3)
        StatusKachel(titel: "Zähler",      symbol: "gauge",                 status: .rot,   erledigt: 0, offen: 15)
        StatusKachel(titel: "Rechnungen",  symbol: "doc.text",              status: .gelb,  erledigt: 7, inArbeit: 1, offen: 2)
        StatusKachel(titel: "Kostenarten", symbol: "list.bullet.rectangle", status: .gruen, erledigt: 10)
    }
    .padding()
}
