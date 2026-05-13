import SwiftUI

struct OnboardingView: View {
    @AppStorage("hatOnboardingGesehen") private var hatGesehen = false

    @State private var currentPage = 0
    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar — Überspringen (ab Screen 1, also auf allen 3 Screens)
            HStack {
                Spacer()
                Button {
                    beenden()
                } label: {
                    Text("Überspringen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .accessibilityLabel("Onboarding überspringen")
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.md)

            // Paged Content
            TabView(selection: $currentPage) {
                screen1.tag(0)
                screen2.tag(1)
                screen3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: currentPage)

            // Custom Page Dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage
                              ? AppTheme.accent
                              : AppTheme.textTertiary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.vertical, AppSpacing.md)
            .accessibilityLabel("Seite \(currentPage + 1) von \(totalPages)")

            // Bottom Buttons
            bottomButtons
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.bottom, AppSpacing.lg)
        }
    }

    // MARK: - Screen 1: Welcome

    private var screen1: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            logoView
                .padding(.bottom, AppSpacing.md)

            Text("NK-Prüfer")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("KI-Prüfung für Mieter")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            Text("Fotografiere deine Nebenkostenabrechnung — unsere KI findet Fehler und erstellt dir einen Widerspruch.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.sm)

            // v4-15: Preis-Hinweis. Räumt vorab die Befürchtung „Paywall am
            // Ende" aus — die App ist kostenlos, nur der eigene Key kostet.
            Text("Kostenlos nutzbar mit eigenem Zugangsschlüssel.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.xs)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.contentPadding)
    }

    private var logoView: some View {
        // v4-13: einheitliches In-App-Logo (Pendant zum App-Icon).
        // Statt Gradient-Square mit Shield zeigt der Onboarding-Screen 1
        // jetzt dasselbe Logo wie HomeView — Haus mit grünem Check-Badge.
        NKAppLogo(size: 80)
    }

    // MARK: - Screen 2: Datenschutz

    private var screen2: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Image(systemName: "shield.lock")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                Text("Deine Daten sind geschützt")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            VStack(spacing: AppSpacing.md) {
                datenschutzBlock(
                    farbe: AppTheme.success,
                    titel: "Bleibt auf deinem Gerät",
                    inhalt: "Fotos, Kontodaten, Adressen, Bankverbindungen"
                )
                datenschutzBlock(
                    farbe: AppTheme.accent,
                    titel: "Wird anonymisiert gesendet",
                    inhalt: "Nur der erkannte Text — Namen und IBANs werden ersetzt"
                )
                datenschutzBlock(
                    farbe: AppTheme.warning,
                    titel: "Wird nie gesendet",
                    inhalt: "Fotos, IBANs, BICs, Telefonnummern, Adressen"
                )
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.top, AppSpacing.xl)
    }

    private func datenschutzBlock(farbe: Color, titel: String, inhalt: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(farbe)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(titel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(inhalt)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(farbe.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Screen 3: Drei Schritte

    private var screen3: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Text("So funktioniert's")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                schrittBlock(
                    nummer: 1,
                    titel: "Fotografieren",
                    inhalt: "Halte deine Abrechnung vor die Kamera"
                )
                schrittBlock(
                    nummer: 2,
                    titel: "KI-Prüfung",
                    inhalt: "7 spezialisierte KI-Agenten prüfen deine Abrechnung"
                )
                schrittBlock(
                    nummer: 3,
                    titel: "Widerspruch",
                    inhalt: "Bei Fehlern erstellen wir dir einen fertigen Widerspruch"
                )
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.top, AppSpacing.xl)
    }

    private func schrittBlock(nummer: Int, titel: String, inhalt: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 36, height: 36)
                Text("\(nummer)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(inhalt)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(nummer): \(titel). \(inhalt)")
    }

    // MARK: - Bottom Buttons

    @ViewBuilder
    private var bottomButtons: some View {
        switch currentPage {
        case 0:
            NKPrimaryButton("Weiter", icon: "arrow.right") {
                withAnimation { currentPage = 1 }
            }
        case 1:
            HStack(spacing: AppSpacing.sm) {
                NKSecondaryButton("Zurück") {
                    withAnimation { currentPage = 0 }
                }
                NKPrimaryButton("Weiter", icon: "arrow.right") {
                    withAnimation { currentPage = 2 }
                }
            }
        case 2:
            HStack(spacing: AppSpacing.sm) {
                NKSecondaryButton("Zurück") {
                    withAnimation { currentPage = 1 }
                }
                NKPrimaryButton("Los geht's", icon: "checkmark") {
                    beenden()
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func beenden() {
        NKHaptic.success()
        withAnimation { hatGesehen = true }
    }
}

#Preview {
    OnboardingView()
}
