import SwiftUI

struct PrivacyConsentView: View {
    @EnvironmentObject var privacyConsent: PrivacyConsent
    @Environment(\.dismiss) private var dismiss

    /// Callback nach Zustimmung — wird vom Aufrufer optional gesetzt
    /// um direkt weiterzumachen (z. B. Pipeline starten).
    var onAccept: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.sm)

                    Text("Datenschutz-Hinweis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Group {
                        infoBlock(
                            icon: "doc.text.magnifyingglass",
                            title: "Was wird verarbeitet?",
                            text: "Der Text deiner Nebenkostenabrechnung wird zur Analyse an Claude (Anthropic) gesendet. Dies kann Adressen, Beträge und Kostenaufstellungen enthalten. Anthropic ist das Unternehmen hinter der KI Claude."
                        )
                        infoBlock(
                            icon: "iphone.and.arrow.forward",
                            title: "Was verlässt dein Gerät?",
                            text: "Nur der extrahierte Text — keine Fotos, keine Kontodaten, keine Bankverbindungen. Namen und Adressen werden vor dem Senden anonymisiert."
                        )
                        infoBlock(
                            icon: "server.rack",
                            title: "Wo werden die Daten verarbeitet?",
                            text: "Die App nutzt die Anthropic API (Claude). Gemäß Anthropics API-Nutzungsbedingungen (Stand 2025) werden API-Daten nicht für KI-Training verwendet und nach 7 Tagen automatisch gelöscht. Details: anthropic.com/privacy"
                        )
                        infoBlock(
                            icon: "hand.raised",
                            title: "Deine Rechte",
                            text: "Du kannst die Zustimmung jederzeit in den Einstellungen widerrufen. Ohne Zustimmung werden keine Daten gesendet — die App funktioniert dann nur mit lokalen Prüfungen."
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.bottom, 120)
            }
            .background(AppTheme.screenBg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: AppSpacing.sm) {
                    NKPrimaryButton("Ich stimme zu") {
                        privacyConsent.erteileZustimmung()
                        NKHaptic.success()
                        let cb = onAccept
                        dismiss()
                        cb?()
                    }

                    NKSecondaryButton("Ablehnen") {
                        dismiss()
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.sm)
                .background(.regularMaterial)
            }
            .navigationTitle("Datenschutz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func infoBlock(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    PrivacyConsentView()
        .environmentObject(PrivacyConsent())
}
