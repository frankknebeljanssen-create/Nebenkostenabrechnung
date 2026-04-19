//
//  CompletionRing.swift
//  NebenkostenApp — UI/Objekt/Components
//

import SwiftUI

struct CompletionRing: View {
    /// 0.0 … 1.0
    let prozent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 18)

            Circle()
                .trim(from: 0, to: max(0, min(1, prozent)))
                .stroke(
                    ringFarbe,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: prozent)

            VStack(spacing: 2) {
                Text("\(Int((prozent * 100).rounded())) %")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("vollständig")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Abrechnung zu \(Int((prozent * 100).rounded())) Prozent vollständig.")
    }

    private var ringFarbe: Color {
        switch prozent {
        case ..<0.34: return .red
        case ..<0.67: return .orange
        default:      return .green
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        CompletionRing(prozent: 0.25)
        CompletionRing(prozent: 0.6)
        CompletionRing(prozent: 0.95)
    }
    .padding()
}
