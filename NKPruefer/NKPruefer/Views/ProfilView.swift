import SwiftUI

/// v4-Profil-Ansicht.
///
/// Migriert die „Meine Daten"-Felder aus der alten SettingsView.
/// Bindet direkt an das `UserProfile`-Environment-Object (mit
/// `@Published`/UserDefaults-Backing — d. h. Speichern ist implizit
/// bei jeder Änderung, der Button gibt nur visuelles Feedback).
struct ProfilView: View {
    @EnvironmentObject var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var zeigeSpeichernToast = false

    // Lokale Eingabe-Felder — werden beim Speichern in UserProfile geschrieben.
    @State private var vorname: String = ""
    @State private var nachname: String = ""
    @State private var strasse: String = ""
    @State private var plz: String = ""
    @State private var ort: String = ""
    @State private var telefon: String = ""
    @State private var email: String = ""

    private var alleAuthFelderGefuellt: Bool {
        !vorname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nachname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !strasse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        plz.trimmingCharacters(in: .whitespacesAndNewlines).count == 5 &&
        !ort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Profil", showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    pflichtSection
                    optionalSection
                    NKPrimaryButton("Speichern", icon: "checkmark") {
                        speichern()
                    }
                }
                .padding(AppSpacing.contentPadding)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if zeigeSpeichernToast {
                speichernToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, AppSpacing.xxl)
            }
        }
        .onAppear { ladeAusProfil() }
    }

    // MARK: - Pflicht-Felder

    private var pflichtSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NKSectionLabel(text: "Angaben für den Widerspruch")

            feldMitLabel("Vorname", pflicht: true) {
                TextField("Max", text: $vorname)
                    .textContentType(.givenName)
                    .textFieldStyle(.roundedBorder)
            }

            feldMitLabel("Nachname", pflicht: true) {
                TextField("Mustermann", text: $nachname)
                    .textContentType(.familyName)
                    .textFieldStyle(.roundedBorder)
            }

            feldMitLabel("Straße und Hausnummer", pflicht: true) {
                TextField("Musterstr. 12", text: $strasse)
                    .textContentType(.streetAddressLine1)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .top, spacing: AppSpacing.md) {
                feldMitLabel("PLZ", pflicht: true) {
                    TextField("12345", text: $plz)
                        .textContentType(.postalCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: plz) { _, neu in
                            // Auf 5 Stellen begrenzen, nur Ziffern erlauben
                            let gefiltert = neu.filter(\.isNumber).prefix(5)
                            if String(gefiltert) != plz {
                                plz = String(gefiltert)
                            }
                        }
                }
                .frame(width: 110)

                feldMitLabel("Ort", pflicht: true) {
                    TextField("Berlin", text: $ort)
                        .textContentType(.addressCity)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Optionale Felder

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NKSectionLabel(text: "Optional")

            feldMitLabel("Telefon", pflicht: false) {
                TextField("0151 12345678", text: $telefon)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                hinweisText("Optional — für den Widerspruch nicht nötig")
            }

            feldMitLabel("E-Mail", pflicht: false) {
                TextField("max@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                hinweisText("Optional — für den Widerspruch nicht nötig")
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func feldMitLabel<Content: View>(
        _ label: String,
        pflicht: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if pflicht {
                    Text("*")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.error)
                }
            }
            content()
        }
    }

    private func hinweisText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
    }

    private var speichernToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text("Profil gespeichert")
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.black.opacity(0.85))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func ladeAusProfil() {
        vorname = userProfile.vorname
        nachname = userProfile.nachname
        strasse = userProfile.strasse
        plz = userProfile.plz
        ort = userProfile.ort
        email = userProfile.email
        telefon = UserDefaults.standard.string(forKey: "up_telefon") ?? ""
    }

    private func speichern() {
        userProfile.vorname = vorname.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.nachname = nachname.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.strasse = strasse.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.plz = plz.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.ort = ort.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Telefon wird in UserProfile (noch) nicht persistiert — daher direkt
        // in UserDefaults, damit das Feld trotzdem Bestand hat.
        UserDefaults.standard.set(
            telefon.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "up_telefon"
        )

        if alleAuthFelderGefuellt {
            NKHaptic.success()
        } else {
            // Auch ohne komplette Pflichtfelder speichern — der User kann
            // später ergänzen. Für haptisches Feedback aber „warning".
            NKHaptic.warning()
        }

        withAnimation { zeigeSpeichernToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { zeigeSpeichernToast = false }
        }
    }
}

#Preview {
    NavigationStack { ProfilView() }
        .environmentObject(UserProfile())
}
