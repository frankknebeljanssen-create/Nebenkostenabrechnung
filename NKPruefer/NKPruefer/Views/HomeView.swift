import SwiftUI
import SwiftData

/// v4-Start-Screen (Redesign v4-13).
///
/// Vertikale Struktur, klar und einladend für nicht-technische Nutzer:
///   1. Begrüßung („Hallo Frank" / „Willkommen")
///   2. App-Logo (NKAppLogo) + „NEBENKOSTEN-PRÜFER"
///   3. Headline + Subline
///   4. CTA: „Abrechnung prüfen"
///   5. Aufklappbares „So funktioniert's"
///   6. Letzte Prüfung (oder dezenter Hinweis)
///   7. SecurityStrip
struct HomeView: View {
    @EnvironmentObject var userProfile: UserProfile

    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse)
    private var mietobjekte: [Mietobjekt]

    @AppStorage("howItWorksExpanded") private var howItWorksExpanded: Bool = true

    /// v4-15: Erstsetup-Sheet bei fehlendem Zugangsschlüssel — wird vom
    /// CTA „Abrechnung prüfen" getriggert, wenn die Keychain leer ist.
    @State private var zeigeKeySetup: Bool = false
    /// Programmatischer Navigation-Trigger zur `PreCaptureView` — wird
    /// gesetzt entweder direkt (Key vorhanden) oder nach erfolgreichem
    /// Speichern im Setup-Sheet.
    @State private var navigiereZuCapture: Bool = false

    /// v4-21: Programmatischer Push zur Demo-Analyse.
    @State private var navigiereZuDemo: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                begruessung
                logoBereich
                headlineBereich
                ctaButton
                demoLink
                soFunktionierts
                letztePruefung
                NKSecurityStrip(text: "Deine Daten werden anonymisiert übertragen und nach der Analyse gelöscht")
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MehrView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                }
                .accessibilityLabel("Einstellungen")
            }
        }
        // v4-15: Setup-Sheet bei fehlendem Zugangsschlüssel.
        // Nach erfolgreichem Speichern → automatisch Push in den Capture-Flow.
        .sheet(isPresented: $zeigeKeySetup) {
            ZugangsschluesselSetupSheet {
                navigiereZuCapture = true
            }
        }
        // Programmatischer Push, getriggert vom CTA (wenn Key vorhanden)
        // oder vom Setup-Sheet-Completion (nach erfolgreichem Speichern).
        .navigationDestination(isPresented: $navigiereZuCapture) {
            PreCaptureView()
        }
        // v4-21: Demo-Flow ohne API-Calls
        .navigationDestination(isPresented: $navigiereZuDemo) {
            DemoAnalyseView()
        }
    }

    // MARK: - Demo-Link (v4-21)

    private var demoLink: some View {
        Button {
            navigiereZuDemo = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo ausprobieren")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    Text("Sieh dir an wie eine Prüfung abläuft — ohne eigene Daten.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.xs)
        .accessibilityLabel("Demo-Prüfung mit Beispieldaten ausprobieren")
    }

    // MARK: - CTA-Routing

    /// Tippt der User auf „Abrechnung prüfen", prüfen wir zuerst die
    /// Keychain. Ohne Key → Setup-Sheet vor dem Capture-Flow.
    private func startePruefung() {
        if KeychainService.hasAPIKey {
            navigiereZuCapture = true
        } else {
            zeigeKeySetup = true
        }
    }

    // MARK: - 1.1 Begrüßung

    private var begruessung: some View {
        Text(begruessungsText)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var begruessungsText: String {
        let v = userProfile.vorname.trimmingCharacters(in: .whitespaces)
        return v.isEmpty ? "Willkommen" : "Hallo \(v)"
    }

    // MARK: - 1.2 Logo + App-Name

    private var logoBereich: some View {
        VStack(spacing: AppSpacing.sm) {
            NKAppLogo(size: 60)

            // v4-20 Light-Mode-Fix: `.white` war in Light Mode auf
            // hellem Hintergrund unsichtbar. `AppTheme.textPrimary`
            // ist adaptiv (schwarz im Light, weiß im Dark).
            Text("Nebenkosten-Prüfer")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(2)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 1.3 Headline + Subline

    private var headlineBereich: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Stimmt deine Abrechnung?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Text("Fotografiere deine Unterlagen und wir prüfen sie für dich.")
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 1.4 CTA

    /// v4-15: Button statt NavigationLink — der Tap entscheidet anhand des
    /// Keychain-Status, ob das Setup-Sheet oder der Capture-Flow kommt.
    private var ctaButton: some View {
        Button(action: startePruefung) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "camera.fill")
                Text("Abrechnung prüfen")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .padding(.horizontal, AppSpacing.xs)
        .accessibilityLabel("Abrechnung prüfen")
    }

    // MARK: - 1.5 So funktioniert's (aufklappbar)

    private var soFunktionierts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    howItWorksExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("So funktioniert's")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .rotationEffect(.degrees(howItWorksExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(howItWorksExpanded ? "Tippen zum Zuklappen" : "Tippen zum Aufklappen")

            if howItWorksExpanded {
                NKCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        schrittZeile(nummer: 1, icon: "camera",
                                     text: "Fotografiere deine Abrechnung")
                        schrittZeile(nummer: 2, icon: "doc.text.magnifyingglass",
                                     text: "Wir prüfen automatisch")
                        schrittZeile(nummer: 3, icon: "checkmark.shield",
                                     text: "Du bekommst das Ergebnis")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: howItWorksExpanded)
    }

    private func schrittZeile(nummer: Int, icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 28, height: 28)
                Text("\(nummer)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)

            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(nummer): \(text)")
    }

    // MARK: - 1.6 Letzte Prüfung

    @ViewBuilder
    private var letztePruefung: some View {
        if let pair = neuesteAbrechnung {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Letzte Prüfung")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    PruefberichtDetailView(abrechnung: pair.1, mietobjekt: pair.0)
                } label: {
                    LetztePruefungCard(mietobjekt: pair.0, abrechnung: pair.1)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("Du hast noch keine Abrechnung geprüft.")
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private var neuesteAbrechnung: (Mietobjekt, GespeicherteAbrechnung)? {
        let paare = mietobjekte.compactMap { obj -> (Mietobjekt, GespeicherteAbrechnung)? in
            guard let a = obj.letzteAbrechnung else { return nil }
            return (obj, a)
        }
        return paare.max(by: { $0.1.pruefDatum < $1.1.pruefDatum })
    }
}

// MARK: - LetztePruefungCard

private struct LetztePruefungCard: View {
    let mietobjekt: Mietobjekt
    let abrechnung: GespeicherteAbrechnung

    var body: some View {
        NKCard {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(subline)
                        .font(AppTypography.hint)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 2) {
                    Text("Ansehen")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var headline: String {
        if let bez = mietobjekt.bezeichnung?.trimmingCharacters(in: .whitespaces), !bez.isEmpty {
            return bez
        }
        return mietobjekt.adresse
    }

    private var subline: String {
        let datum = abrechnung.pruefDatumFormatiert
        let anzahl = (abrechnung.ladeBericht()?.findings.count) ?? 0
        let label = anzahl == 1 ? "Ergebnis" : "Ergebnisse"
        return "\(datum) · \(anzahl) \(label)"
    }
}

#Preview("Erstmalig") {
    NavigationStack { HomeView() }
        .environmentObject(UserProfile())
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
