import SwiftUI
import UIKit

struct VermieterDatenSheet: View {
    let mietobjekt: Mietobjekt
    let onComplete: () -> Void

    @EnvironmentObject var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var vermieterName = ""
    @State private var vermieterAdresse = ""

    @State private var nameHasError = false
    @State private var adresseHasError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch ein paar Angaben")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Für den Widerspruch brauchen wir die Daten deines Vermieters.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NKTextField(
                        label: "Name des Vermieters / Hausverwaltung",
                        placeholder: "Mustermann Hausverwaltung",
                        text: $vermieterName,
                        textContentType: .organizationName,
                        isRequired: true,
                        hasError: nameHasError,
                        errorText: "Bitte gib den Namen des Vermieters an."
                    )

                    NKTextField(
                        label: "Adresse des Vermieters",
                        placeholder: "Beispielweg 5, 12345 Berlin",
                        text: $vermieterAdresse,
                        textContentType: .fullStreetAddress,
                        isRequired: true,
                        hasError: adresseHasError,
                        errorText: "Bitte gib die Adresse des Vermieters an."
                    )

                    if !userProfile.hatName {
                        NKInfoBox(text: "Gib deinen Namen in den Einstellungen unter „Meine Daten“ ein, damit er im Briefkopf erscheint.")
                    }

                    NKBigButton(title: "Weiter zum Widerspruch", icon: "checkmark", style: .success) {
                        speichern()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Vermieter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear(perform: ladeBestehendes)
        }
    }

    // MARK: - Actions

    private func ladeBestehendes() {
        if let v = mietobjekt.vermieterName?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            vermieterName = v
        }
        if let a = mietobjekt.vermieterAdresse?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
            vermieterAdresse = a
        }
    }

    private func speichern() {
        let vName = vermieterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let vAdr = vermieterAdresse.trimmingCharacters(in: .whitespacesAndNewlines)

        nameHasError = vName.isEmpty
        adresseHasError = vAdr.isEmpty

        guard !nameHasError, !adresseHasError else {
            NKHaptic.error()
            return
        }

        mietobjekt.vermieterName = vName
        mietobjekt.vermieterAdresse = vAdr

        NKHaptic.success()
        dismiss()
        onComplete()
    }
}
