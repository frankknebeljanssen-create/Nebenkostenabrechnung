import SwiftUI

/// v4-Datenschutz-Einstellungen.
///
/// Migriert die DSGVO-Consent-UI aus der alten SettingsView:
///  • Bei erteilter Zustimmung: Status + Datum + roter „Widerrufen"-Button
///  • Bei fehlender Zustimmung: Hinweis + „Erteilen"-Button, der die
///    bestehende `PrivacyConsentView` als Sheet öffnet
struct DatenschutzSettingsView: View {
    @EnvironmentObject var privacyConsent: PrivacyConsent

    @State private var zeigeConsentSheet = false
    @State private var zeigeWiderrufBestaetigung = false

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Datenschutz", showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if privacyConsent.hatZugestimmt {
                        statusErteilt
                        widerrufenButton
                    } else {
                        statusFehlend
                        erteilenButton
                    }

                    erklaerungsBlock
                }
                .padding(AppSpacing.contentPadding)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $zeigeConsentSheet) {
            PrivacyConsentView()
                .environmentObject(privacyConsent)
        }
        .alert("Zustimmung widerrufen?", isPresented: $zeigeWiderrufBestaetigung) {
            Button("Widerrufen", role: .destructive) {
                privacyConsent.widerrufeZustimmung()
                NKHaptic.warning()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ohne Zustimmung können keine Abrechnungen mehr an die KI gesendet werden. Lokale Funktionen bleiben verfügbar.")
        }
    }

    // MARK: - Status: erteilt

    private var statusErteilt: some View {
        NKCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.success)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Datenschutz-Zustimmung erteilt")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let datum = privacyConsent.consentDatum {
                        Text("Am \(datum.formatted(.dateTime.day().month(.wide).year()))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var widerrufenButton: some View {
        Button {
            zeigeWiderrufBestaetigung = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                Text("Widerrufen")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.error)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(AppTheme.error.opacity(0.4), lineWidth: 0.8)
            )
        }
        .accessibilityLabel("Datenschutz-Zustimmung widerrufen")
    }

    // MARK: - Status: fehlend

    private var statusFehlend: some View {
        NKCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.warning)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Keine Zustimmung erteilt")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Ohne Zustimmung können keine Abrechnungen geprüft werden.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var erteilenButton: some View {
        NKPrimaryButton("Erteilen", icon: "checkmark") {
            zeigeConsentSheet = true
        }
    }

    // MARK: - Erklärung

    private var erklaerungsBlock: some View {
        NKCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Was wird verarbeitet?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Der Text deiner Nebenkostenabrechnung wird zur Analyse an Claude (Anthropic) gesendet. Namen, IBANs und andere persönliche Daten werden vor dem Senden anonymisiert.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack { DatenschutzSettingsView() }
        .environmentObject(PrivacyConsent())
}
