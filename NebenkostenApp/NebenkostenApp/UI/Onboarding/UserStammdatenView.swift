//
//  UserStammdatenView.swift
//  NebenkostenApp — UI/Onboarding
//

import SwiftUI

struct UserStammdatenView: View {
    @Bindable var controller: OnboardingController

    var body: some View {
        Form {
            Section("Ihre Daten") {
                TextField("Name (Pflicht)", text: $controller.userName)
                    .textContentType(.name)
                TextField("Straße und Hausnummer", text: $controller.userAnschrift)
                    .textContentType(.streetAddressLine1)
                TextField("PLZ und Ort", text: $controller.userOrt)
                    .textContentType(.addressCity)
                TextField("E-Mail (Pflicht)", text: $controller.userEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Telefon (optional)", text: $controller.userTelefon)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }

            Section("Rolle") {
                Picker("Rolle", selection: $controller.userRolle) {
                    ForEach(UserRolle.allCases, id: \.self) { rolle in
                        Text(rolle.rawValue).tag(rolle)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Optional") {
                TextField("Steuer-ID (optional)", text: $controller.userSteuerID)
                TextField("IBAN (optional)", text: $controller.userIban)
                    .textInputAutocapitalization(.characters)
            }

            Section {
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
                    .disabled(!controller.darfVonUserStammdatenWeiter)
                }
            }
        }
        .navigationTitle("Stammdaten")
        .navigationBarTitleDisplayMode(.inline)
    }
}
