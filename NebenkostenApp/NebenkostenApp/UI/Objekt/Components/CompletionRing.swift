//
//  CompletionRing.swift
//  NebenkostenApp — UI/Objekt/Components
//
//  Fortschrittsanzeige der Abrechnungs-Vorbereitung für die aktuelle
//  Periode. Ursprünglich als 180×180-Ring gebaut; seit v0.22 als
//  Querbalken, weil das Dashboard sonst zu viel vertikalen Platz
//  verbraucht (~196pt → ~44pt).
//

import SwiftUI

struct CompletionBalken: View {
    /// 0.0 … 1.0
    let prozent: Double

    private var geklammert: Double { max(0, min(1, prozent)) }
    private var prozentText: String { "\(Int((geklammert * 100).rounded())) %" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(prozentText)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(balkenFarbe)
                Text("vollständig")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(balkenFarbe)
                        .frame(width: proxy.size.width * geklammert)
                        .animation(.easeInOut(duration: 0.4), value: geklammert)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Abrechnung zu \(Int((geklammert * 100).rounded())) Prozent vollständig.")
    }

    private var balkenFarbe: Color {
        switch geklammert {
        case ..<0.34: return .red
        case ..<0.67: return .orange
        default:      return .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBalken(prozent: 0.25)
        CompletionBalken(prozent: 0.6)
        CompletionBalken(prozent: 0.95)
    }
    .padding()
}
