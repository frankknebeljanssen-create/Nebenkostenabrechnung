//
//  WillkommenView.swift
//  NebenkostenApp — UI/Onboarding
//

import SwiftUI

struct WillkommenView: View {
    @Bindable var controller: OnboardingController

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)
            Text("NebenkostenApp")
                .font(.largeTitle.bold())
            Text("Willkommen!")
                .font(.title2)
            Text("""
            Die NebenkostenApp hilft Ihnen als Vermieterin, die \
            Nebenkostenabrechnung für Ihre Mieter sicher und rechtskonform \
            zu erstellen. Alle Daten bleiben in Ihrem privaten \
            iCloud-Account — niemand außer Ihnen hat darauf Zugriff.
            """)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button {
                controller.weiter()
            } label: {
                Text("Los geht's")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
