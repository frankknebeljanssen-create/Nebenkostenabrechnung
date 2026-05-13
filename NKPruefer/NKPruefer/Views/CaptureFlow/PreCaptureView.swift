import SwiftUI

/// v4-PreCapture-Screen — die Erklärseite vor dem Kamera-Start.
///
/// Layout-Regeln (v4-11):
///   • System-NavigationBar mit nativem Back-Button (kein NKHeader,
///     der mit Content überlappt)
///   • 3 NummerKarten, gestapelt mit konsistentem Spacing
///   • Info-Box + primärer „Kamera öffnen"-Button am unteren Rand
///   • Bottom-Padding für Tab-Bar-Clearance
struct PreCaptureView: View {
    @State private var auftrag = PruefungsAuftrag()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("So funktioniert's")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    NummerKarte(
                        nummer: 1,
                        icon: "camera",
                        text: "Fotografiere die Seiten mit Beträgen und Kostenaufstellung — meistens 2–4 Seiten"
                    )
                    NummerKarte(
                        nummer: 2,
                        icon: "doc.text.magnifyingglass",
                        text: "Wir prüfen automatisch"
                    )
                    NummerKarte(
                        nummer: 3,
                        icon: "checkmark.shield",
                        text: "Du bekommst das Ergebnis sofort"
                    )
                }

                NKCard {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 2)
                        Text("Gleich fragt dein Handy, ob die App die Kamera benutzen darf. Tippe auf „Erlauben“.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NavigationLink {
                    CaptureView(auftrag: auftrag)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "camera.fill")
                        Text("Kamera öffnen")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.contentPadding)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Abrechnung prüfen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Nummerierte Karte
//
// Eine Zeile pro Schritt: links Nummer in Kreis, mittig Icon, rechts Text.
// Alles in einer HStack — kein ZStack/Overlay, damit nichts überlappt.

private struct NummerKarte: View {
    let nummer: Int
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("\(nummer)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(nummer): \(text)")
    }
}

#Preview {
    NavigationStack { PreCaptureView() }
}
