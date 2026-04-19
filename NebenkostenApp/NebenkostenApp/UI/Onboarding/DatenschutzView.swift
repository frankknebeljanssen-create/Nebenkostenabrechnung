//
//  DatenschutzView.swift
//  NebenkostenApp — UI/Onboarding
//

import SwiftUI

struct DatenschutzView: View {
    @Bindable var controller: OnboardingController

    var body: some View {
        VStack(spacing: 16) {
            Text("Datenschutzerklärung")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                Text(LegalTexts.datenschutzPlatzhalter)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))

            Toggle(isOn: $controller.datenschutzAkzeptiert) {
                Text("Ich akzeptiere die Datenschutzerklärung.")
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
                .disabled(!controller.darfVonDatenschutzWeiter)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}
