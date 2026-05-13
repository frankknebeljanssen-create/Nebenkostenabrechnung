import SwiftUI

/// v4-„Zugangsschlüssel"-Ansicht (intern: API-Key in der Keychain).
///
/// Migriert die „API-Zugang"-Sektion aus der alten SettingsView:
///  • Status-Anzeige (grünes Schild bei vorhandenem Key, orange Warnung sonst)
///  • Eingabe-Button mit Alert + TextField („sk-ant-...")
///  • Footer-Hinweis zur sicheren Keychain-Speicherung
///
/// SPRACHE: In der UI sagen wir „Zugangsschlüssel" statt „API-Key".
/// Interne Variablen (`apiKeyInput`, `KeychainService.saveAPIKey`)
/// bleiben unverändert englisch.
struct ZugangsschluesselView: View {
    @State private var zeigeEingabe = false
    @State private var apiKeyInput = ""
    @State private var apiKeyVorhanden = KeychainService.hasAPIKey
    @State private var zeigeEntfernenBestaetigung = false

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Zugangsschlüssel", showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    kopfBlock
                    statusBlock
                    aktionsBlock
                    footerBlock
                }
                .padding(AppSpacing.contentPadding)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Zugangsschlüssel eingeben", isPresented: $zeigeEingabe) {
            TextField("sk-ant-...", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Speichern") {
                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, KeychainService.saveAPIKey(trimmed) {
                    apiKeyVorhanden = true
                    NKHaptic.success()
                } else {
                    NKHaptic.error()
                }
                apiKeyInput = ""
            }
            Button("Abbrechen", role: .cancel) { apiKeyInput = "" }
        } message: {
            Text("Gib deinen Anthropic-Zugangsschlüssel ein. Er wird sicher in der iOS Keychain gespeichert.")
        }
        .alert("Zugangsschlüssel entfernen?", isPresented: $zeigeEntfernenBestaetigung) {
            Button("Entfernen", role: .destructive) {
                KeychainService.deleteAPIKey()
                apiKeyVorhanden = false
                NKHaptic.warning()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ohne Zugangsschlüssel können keine Abrechnungen geprüft werden.")
        }
    }

    // MARK: - Kopf

    private var kopfBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Eigener Zugangsschlüssel")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Für Entwickler und Nutzer mit eigenem Anthropic-Konto.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBlock: some View {
        if apiKeyVorhanden {
            NKCard {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.success)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zugangsschlüssel gespeichert")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Verschlüsselt in der iOS Keychain.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        } else {
            NKCard {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.warning)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kein Zugangsschlüssel hinterlegt")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Ohne Schlüssel kann die App keine Abrechnungen prüfen.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Aktionen

    @ViewBuilder
    private var aktionsBlock: some View {
        if apiKeyVorhanden {
            VStack(spacing: AppSpacing.sm) {
                NKPrimaryButton("Zugangsschlüssel ändern", icon: "pencil") {
                    zeigeEingabe = true
                }
                NKSecondaryButton("Entfernen", icon: "trash") {
                    zeigeEntfernenBestaetigung = true
                }
            }
        } else {
            NKPrimaryButton("Zugangsschlüssel eingeben", icon: "key") {
                zeigeEingabe = true
            }
        }
    }

    // MARK: - Footer

    private var footerBlock: some View {
        Text("Der Zugangsschlüssel wird verschlüsselt in der iOS Keychain gespeichert und verlässt das Gerät nicht.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack { ZugangsschluesselView() }
}
