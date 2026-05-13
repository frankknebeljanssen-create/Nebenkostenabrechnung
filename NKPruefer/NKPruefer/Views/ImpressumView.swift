import SwiftUI

/// v4-15 — Impressum / Über diese App.
///
/// Erreichbar aus `MehrView` → Sektion „Über". Zeigt App-Beschreibung,
/// rechtlichen Hinweis (kein RDG-konformer Rechtsrat), Verantwortlich-
/// Block (von Frank manuell zu füllen), Preis-Hinweis und externe Links.
struct ImpressumView: View {

    private let datenschutzURL = URL(string: "https://www.anthropic.com/privacy")!
    private let nutzungURL     = URL(string: "https://www.anthropic.com/legal/consumer-terms")!

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Über diese App", showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    titelBlock
                    ueberDieAppBlock
                    rechtlicherHinweisBlock
                    verantwortlichBlock
                    linksBlock

                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Titel + Version

    private var titelBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nebenkosten-Prüfer")
                .font(.system(size: 14, weight: .medium))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.accent)

            Text(versionString)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Über die App

    private var ueberDieAppBlock: some View {
        sektion(titel: "Über die App") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Der Nebenkosten-Prüfer hilft dir, Fehler in deiner Nebenkostenabrechnung zu finden und einen Widerspruch zu erstellen.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Die App nutzt künstliche Intelligenz (Claude von Anthropic), um deine Abrechnung zu analysieren. Deine Daten werden dabei anonymisiert.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Preis-Hinweis (Fix 7)
                Text("Die App ist kostenlos. Für die KI-Analyse benötigst du einen eigenen Zugangsschlüssel (API-Key) von Anthropic. Dabei können Kosten bei Anthropic anfallen.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Rechtlicher Hinweis

    private var rechtlicherHinweisBlock: some View {
        sektion(titel: "Rechtlicher Hinweis", icon: "scale.3d") {
            Text("Diese App bietet keine Rechtsberatung im Sinne des Rechtsdienstleistungsgesetzes (RDG). Die Analyse-Ergebnisse sind automatisch generiert und können Fehler enthalten. Im Zweifel wende dich an deinen örtlichen Mieterverein oder einen Fachanwalt für Mietrecht.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Verantwortlich (Placeholder)

    private var verantwortlichBlock: some View {
        sektion(titel: "Verantwortlich", icon: "person.crop.circle") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("[Name / Firma einfügen]")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("[Adresse einfügen]")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("[Email einfügen]")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)

                Divider()
                    .padding(.vertical, AppSpacing.xs)

                Text("Datenschutz-Verantwortlicher gemäß Art. 4 Nr. 7 DSGVO:")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("[Name einfügen]")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    // MARK: - Links

    private var linksBlock: some View {
        sektion(titel: "Links", icon: "link") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Link(destination: datenschutzURL) {
                    HStack(spacing: 6) {
                        Text("Anthropic Datenschutz")
                            .font(.system(size: 14, weight: .medium))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(AppTheme.accent)
                }

                Divider()

                Link(destination: nutzungURL) {
                    HStack(spacing: 6) {
                        Text("Anthropic Nutzungsbedingungen")
                            .font(.system(size: 14, weight: .medium))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Card-Helper

    @ViewBuilder
    private func sektion<Content: View>(
        titel: String,
        icon: String? = nil,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                }
                Text(titel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            content()
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    NavigationStack { ImpressumView() }
}
