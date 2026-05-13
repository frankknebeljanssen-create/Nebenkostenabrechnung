import SwiftUI

/// v4-15 — Erstsetup-Sheet für den Zugangsschlüssel (API-Key).
///
/// Wird automatisch präsentiert, wenn der User auf „Abrechnung prüfen" tippt
/// und noch kein Key in der Keychain liegt. Erklärt Schritt-für-Schritt,
/// wo der Key herkommt, validiert das Format, speichert in der Keychain
/// und ruft `onCompleted` → HomeView navigiert dann in den Capture-Flow.
///
/// `ZugangsschluesselView` (in MehrView) bleibt als Edit-Surface bestehen.
struct ZugangsschluesselSetupSheet: View {

    /// Wird gerufen sobald ein gültiger Key erfolgreich gespeichert wurde.
    /// HomeView pusht daraufhin `PreCaptureView`.
    let onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var keyInput: String = ""
    @State private var fehlertext: String? = nil
    @State private var laeuft: Bool = false

    private let anthropicURL = URL(string: "https://console.anthropic.com")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    hero
                    erklaerung
                    schritteCard
                    eingabeFeld
                    consoleLink
                    speichernButton
                    securityStrip
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppTheme.screenBg.ignoresSafeArea())
            .navigationTitle("Zugangsschlüssel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .accessibilityLabel("Schließen")
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "key.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            Text("Zugangsschlüssel einrichten")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var erklaerung: some View {
        Text("Damit die App deine Abrechnung prüfen kann, braucht sie einen Zugangsschlüssel. Das ist wie ein Passwort, das die App berechtigt, die KI-Analyse zu nutzen.")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 5 Schritte

    private var schritteCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("So bekommst du einen:")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                schrittZeile(1, "Öffne console.anthropic.com")
                schrittZeile(2, "Erstelle ein kostenloses Konto")
                schrittZeile(3, "Gehe zu „API Keys\u{201C}")
                schrittZeile(4, "Erstelle einen neuen Key")
                schrittZeile(5, "Kopiere ihn und füge ihn unten ein")
            }
            .padding(AppSpacing.md)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }

    private func schrittZeile(_ nummer: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("\(nummer).")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 18, alignment: .leading)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Eingabe

    private var eingabeFeld: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SecureField("Schlüssel eingeben (sk-ant-…)", text: $keyInput)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(AppSpacing.md)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                        .stroke(fehlertext == nil ? AppTheme.border : AppTheme.error,
                                lineWidth: 0.5)
                )
                .onChange(of: keyInput) { _, _ in
                    // Fehler verschwindet sobald der User tippt
                    if fehlertext != nil { fehlertext = nil }
                }

            if let fehlertext {
                Text(fehlertext)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var consoleLink: some View {
        Link(destination: anthropicURL) {
            HStack(spacing: 6) {
                Image(systemName: "safari")
                    .font(.system(size: 14))
                Text("console.anthropic.com öffnen")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
            }
            .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Speichern

    private var speichernButton: some View {
        Button {
            speichereKey()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if laeuft {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text("Speichern & weiter")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(istEingabeGueltig ? AppTheme.accent : AppTheme.border)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .disabled(!istEingabeGueltig || laeuft)
        .accessibilityLabel("Schlüssel speichern und Prüfung starten")
    }

    /// Format-Plausibilität ohne Server-Call: `sk-ant-` + ≥20 Zeichen total.
    private var istEingabeGueltig: Bool {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("sk-ant-") && trimmed.count >= 20
    }

    private func speichereKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard istEingabeGueltig else {
            fehlertext = "Bitte gib einen gültigen Schlüssel ein (beginnt mit „sk-ant-\u{201C})."
            NKHaptic.error()
            return
        }
        laeuft = true
        if KeychainService.saveAPIKey(trimmed) {
            NKHaptic.success()
            laeuft = false
            dismiss()
            // dismiss() ist async; CTA-Callback erst NACH dismiss feuern,
            // damit HomeView seinen NavigationLink stabil pushen kann.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onCompleted()
            }
        } else {
            laeuft = false
            fehlertext = "Speichern in der Keychain ist fehlgeschlagen. Bitte später erneut versuchen."
            NKHaptic.error()
        }
    }

    // MARK: - Security-Strip

    private var securityStrip: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.success)
                .frame(width: 22)
            Text("Dein Schlüssel wird sicher auf deinem Gerät gespeichert und nie an uns übertragen.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .background(AppTheme.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.success.opacity(0.20), lineWidth: 0.5)
        )
    }
}

#Preview {
    ZugangsschluesselSetupSheet(onCompleted: {})
}
