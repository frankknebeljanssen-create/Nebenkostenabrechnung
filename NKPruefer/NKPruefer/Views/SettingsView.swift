import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var privacyConsent: PrivacyConsent
    @Environment(\.modelContext) private var modelContext

    @AppStorage("hatOnboardingGesehen") private var hatOnboardingGesehen = false

    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse) var mietobjekte: [Mietobjekt]

    @State private var zeigeNeueWohnung = false
    @State private var editWohnung: Mietobjekt? = nil

    @State private var zeigeAPIKeyEingabe = false
    @State private var apiKeyInput = ""

    @State private var apiKeyVorhanden = KeychainService.hasAPIKey

    @State private var zeigeHistorieLoeschen = false
    @State private var zeigeAllesLoeschen = false

    var body: some View {
        Form {
            meineDatenSection
            darstellungSection
            apiZugangSection
            wohnungenSection
            ueberSection
            datenverwaltungSection
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editWohnung) { obj in
            MietobjektEditView(bestehendesObjekt: obj)
        }
        .sheet(isPresented: $zeigeNeueWohnung) {
            MietobjektEditView()
        }
        .alert("Verlauf löschen?", isPresented: $zeigeHistorieLoeschen) {
            Button("Löschen", role: .destructive) {
                _ = DataDeletionService.deleteHistory(modelContext: modelContext)
                NKHaptic.success()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle gespeicherten Prüfberichte werden unwiderruflich gelöscht.")
        }
        .alert("Alle Daten löschen?", isPresented: $zeigeAllesLoeschen) {
            Button("Alles löschen", role: .destructive) {
                _ = DataDeletionService.deleteAllUserData(modelContext: modelContext)
                NKHaptic.warning()
                // App auf Ausgangszustand zurücksetzen
                hatOnboardingGesehen = false
                apiKeyVorhanden = false
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("ACHTUNG: Alle Daten werden unwiderruflich gelöscht — Profil, Wohnungen, Prüfberichte, Zugangsschlüssel und Einstellungen. Die App wird auf den Ausgangszustand zurückgesetzt.")
        }
        .alert("Zugangsschlüssel", isPresented: $zeigeAPIKeyEingabe) {
            TextField("sk-ant-...", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Speichern") {
                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty,
                   KeychainService.saveAPIKey(trimmed) {
                    apiKeyVorhanden = true
                    NKHaptic.success()
                } else {
                    NKHaptic.error()
                }
                apiKeyInput = ""
            }
            Button("Abbrechen", role: .cancel) { apiKeyInput = "" }
        } message: {
            Text("Gib deinen Zugangsschlüssel ein. Er wird sicher in der Keychain gespeichert.")
        }
    }

    // MARK: - Sections

    private var meineDatenSection: some View {
        Section {
            TextField("Vorname", text: $userProfile.vorname)
                .textContentType(.givenName)
            TextField("Nachname", text: $userProfile.nachname)
                .textContentType(.familyName)
            TextField("Straße und Hausnummer", text: $userProfile.strasse)
                .textContentType(.streetAddressLine1)
            HStack {
                TextField("PLZ", text: $userProfile.plz)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                TextField("Ort", text: $userProfile.ort)
                    .textContentType(.addressCity)
            }
            TextField("E-Mail", text: $userProfile.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Meine Daten")
        } footer: {
            Text("Wird für den Briefkopf bei Widersprüchen verwendet.")
        }
    }

    private var darstellungSection: some View {
        Section {
            Picker("Erscheinungsbild", selection: $appSettings.appearanceMode) {
                Text("System").tag(0)
                Text("Hell").tag(1)
                Text("Dunkel").tag(2)
            }
            .pickerStyle(.segmented)

            if BiometricService.isAvailable {
                Toggle(isOn: $appSettings.appLockEnabled) {
                    HStack {
                        Image(systemName: BiometricService.biometricType == "Face ID" ? "faceid" : "touchid")
                        Text("App mit \(BiometricService.biometricType) sperren")
                            .font(.system(size: 15))
                    }
                }
            }
        } header: {
            Text("Darstellung")
        }
    }

    private var apiZugangSection: some View {
        Section {
            if apiKeyVorhanden {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Zugangsschlüssel gespeichert")
                        .font(.system(size: 15))
                    Spacer()
                    Button("Ändern") { zeigeAPIKeyEingabe = true }
                        .font(.system(size: 13))
                }
            } else {
                Button {
                    zeigeAPIKeyEingabe = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Zugangsschlüssel eingeben")
                            .font(.system(size: 15))
                    }
                }
            }
        } header: {
            Text("Zugangsschlüssel")
        } footer: {
            Text("Der Zugangsschlüssel wird verschlüsselt in der iOS Keychain gespeichert und verlässt das Gerät nicht.")
        }
    }

    private var wohnungenSection: some View {
        Section {
            ForEach(mietobjekte) { obj in
                Button {
                    editWohnung = obj
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(obj.adresse)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        if let bez = obj.bezeichnung, !bez.isEmpty {
                            Text(bez)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button("Wohnung hinzufügen") {
                zeigeNeueWohnung = true
            }
        } header: {
            Text("Meine Wohnungen")
        }
    }

    private var ueberSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)

            if privacyConsent.hatZugestimmt {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Datenschutz-Zustimmung")
                            .font(.system(size: 13))
                        if let datum = privacyConsent.consentDatum {
                            Text(datum, style: .date)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Widerrufen") {
                        privacyConsent.widerrufeZustimmung()
                        NKHaptic.warning()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                }
            }

            Text("Diese App ersetzt keine Rechtsberatung. Bei Unstimmigkeiten empfehlen wir einen Mieterverein.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } header: {
            Text("Über die App")
        }
    }

    private var datenverwaltungSection: some View {
        Section {
            NavigationLink {
                AuditLogView()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("API-Protokoll anzeigen")
                        .font(.system(size: 15))
                }
            }

            Button(role: .destructive) {
                zeigeHistorieLoeschen = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Prüfungs-Verlauf löschen")
                        .font(.system(size: 15))
                }
            }

            Button(role: .destructive) {
                zeigeAllesLoeschen = true
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Alle Daten löschen")
                        .font(.system(size: 15))
                }
            }
        } header: {
            Text("Datenverwaltung")
        } footer: {
            Text("„Alle Daten löschen“ entfernt sämtliche gespeicherten Daten unwiderruflich: Profil, Wohnungen, Prüfberichte, Zugangsschlüssel und Einstellungen.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(UserProfile())
        .environmentObject(AppSettings())
        .environmentObject(PrivacyConsent())
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
