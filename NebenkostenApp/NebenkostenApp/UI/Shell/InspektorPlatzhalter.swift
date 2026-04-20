//
//  InspektorPlatzhalter.swift
//  NebenkostenApp — UI/Shell
//
//  Minimal-Stub für das FAB-Sheet. Volle Logik (Vollstaendigkeits-
//  Pruefung, Anforderungs-Liste) aus Task 0.20 wird in UI-1 ins neue
//  Design übertragen.
//

import SwiftUI

struct InspektorPlatzhalter: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignTokens.accent)
                Text("Was fehlt noch?")
                    .appFont(AppFont.heroSaldo())
                    .foregroundStyle(DesignTokens.text)
                Text("Volle Vollständigkeits-Inspektor-View kommt in UI-1 — nutzt dieselbe Daten-Pipeline wie der Phase-0-Inspektor (Task 0.20).")
                    .appFont(AppFont.body())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgSheet)
            .navigationTitle("Inspektor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
