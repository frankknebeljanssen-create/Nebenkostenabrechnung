//
//  FertigView.swift
//  NebenkostenApp — UI/Onboarding
//

import SwiftUI

struct FertigView: View {
    @Bindable var controller: OnboardingController
    let abschluss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88, weight: .semibold))
                .foregroundStyle(.green)

            Text("Alles eingerichtet!")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                zeile(label: "User", wert: controller.userName)
                zeile(label: "E-Mail", wert: controller.userEmail)
                zeile(label: "Rolle", wert: controller.userRolle.rawValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            Button {
                abschluss()
            } label: {
                Text("Zum Dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Button("Zurück") { controller.zurueck() }
                .padding(.bottom, 24)
        }
    }

    private func zeile(label: String, wert: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(wert.isEmpty ? "—" : wert)
                .fontWeight(.medium)
        }
    }
}
