//
//  AvvView.swift
//  NebenkostenApp — UI/Onboarding
//

import SwiftUI

struct AvvView: View {
    @Bindable var controller: OnboardingController

    var body: some View {
        VStack(spacing: 16) {
            Text("Auftragsverarbeitungsvertrag (AVV)")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                Text(LegalTexts.avvPlatzhalter)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))

            Toggle(isOn: $controller.avvAkzeptiert) {
                Text("Ich akzeptiere den AVV.")
                    .font(.callout)
            }
            .padding(.horizontal)

            HStack {
                Button("Zurück") { controller.zurueck() }
                    .buttonStyle(.bordered)
                Spacer()
                Button {
                    controller.weiter()
                } label: {
                    Text("Weiter").frame(minWidth: 88)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controller.darfVonAvvWeiter)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
