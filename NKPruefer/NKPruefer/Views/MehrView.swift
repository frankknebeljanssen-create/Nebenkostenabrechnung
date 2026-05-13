import SwiftUI
import SwiftData

/// v4-„Mehr"-Tab.
///
/// Aufbau (3 Sections):
///  • Meine Daten        → Profil, Meine Wohnungen
///  • App-Einstellungen  → Darstellung, Datenschutz, Zugangsschlüssel
///  • Datenverwaltung    → Prüfungs-Protokoll, Verlauf löschen, Alle Daten löschen
///
/// Die Datenverwaltungs-Alerts wurden 1:1 aus der alten SettingsView
/// übernommen (DataDeletionService.deleteHistory / .deleteAllUserData,
/// hatOnboardingGesehen-Reset nach Full-Delete).
struct MehrView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hatOnboardingGesehen") private var hatOnboardingGesehen = false

    @State private var apiKeyVorhanden = KeychainService.hasAPIKey
    @State private var zeigeHistorieLoeschen = false
    @State private var zeigeAllesLoeschen = false

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Mehr")
            Divider()

            List {
                meineDatenSection
                appEinstellungenSection
                datenverwaltungSection
                ueberSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Status aktualisieren, falls der User in ZugangsschluesselView etwas geändert hat.
            apiKeyVorhanden = KeychainService.hasAPIKey
        }
        .alert("Prüfungs-Verlauf löschen?", isPresented: $zeigeHistorieLoeschen) {
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
    }

    // MARK: - Section 1: Meine Daten

    private var meineDatenSection: some View {
        Section {
            NavigationLink {
                ProfilView()
            } label: {
                rowLabel(icon: "person.crop.circle", text: "Profil")
            }

            NavigationLink {
                MietobjektListView()
            } label: {
                rowLabel(icon: "house", text: "Meine Wohnungen")
            }
        } header: {
            Text("Meine Daten")
        }
    }

    // MARK: - Section 2: App-Einstellungen

    private var appEinstellungenSection: some View {
        Section {
            NavigationLink {
                DarstellungView()
            } label: {
                rowLabel(icon: "paintbrush", text: "Darstellung")
            }

            NavigationLink {
                DatenschutzSettingsView()
            } label: {
                rowLabel(icon: "lock.shield", text: "Datenschutz")
            }

            NavigationLink {
                ZugangsschluesselView()
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "key")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 24)
                    Text("Zugangsschlüssel")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 0)
                    zugangStatusIcon
                }
            }
        } header: {
            Text("App-Einstellungen")
        }
    }

    /// Trailing-Indikator: grünes Häkchen wenn Key vorhanden, orange Warnung sonst.
    @ViewBuilder
    private var zugangStatusIcon: some View {
        if apiKeyVorhanden {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
                .accessibilityLabel("Zugangsschlüssel vorhanden")
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
                .accessibilityLabel("Kein Zugangsschlüssel hinterlegt")
        }
    }

    // MARK: - Section 3: Datenverwaltung

    private var datenverwaltungSection: some View {
        Section {
            NavigationLink {
                AuditLogView()
            } label: {
                rowLabel(icon: "doc.text.magnifyingglass", text: "Prüfungs-Protokoll")
            }

            Button(role: .destructive) {
                zeigeHistorieLoeschen = true
            } label: {
                rowLabel(icon: "trash", text: "Prüfungsverlauf löschen", tint: AppTheme.error)
            }

            Button(role: .destructive) {
                zeigeAllesLoeschen = true
            } label: {
                rowLabel(icon: "exclamationmark.triangle", text: "Alle Daten löschen", tint: AppTheme.error)
            }
        } header: {
            Text("Datenverwaltung")
        } footer: {
            Text("\u{201E}Alle Daten löschen\u{201C} entfernt sämtliche gespeicherten Daten unwiderruflich: Profil, Wohnungen, Prüfberichte, Zugangsschlüssel und Einstellungen.")
        }
    }

    // MARK: - Section 4: Über (v4-15)

    /// Impressum / Über-uns-Eintrag. Bewusst ganz unten, separat von den
    /// Einstellungs-Sektionen — folgt iOS-Konvention.
    private var ueberSection: some View {
        Section {
            NavigationLink {
                ImpressumView()
            } label: {
                rowLabel(icon: "info.circle", text: "Über diese App")
            }
        } header: {
            Text("Über")
        }
    }

    // MARK: - Row-Builder

    private func rowLabel(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(tint ?? AppTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(tint ?? AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack { MehrView() }
        .environmentObject(UserProfile())
        .environmentObject(AppSettings())
        .environmentObject(PrivacyConsent())
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self], inMemory: true)
}
