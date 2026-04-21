//
//  AppShellChrome.swift
//  NebenkostenApp — UI/Shell
//
//  ViewModifier fuer jeden Tab-Content: legt den permanenten
//  `KontextHeader` (Objekt/Periode/WE-Pills) oben an, gefolgt von
//  einer schmalen NavBar mit optionalem Plex-Sans-Titel 30 pt und
//  rechts Einstellungen-/Primary-Action-Buttons.
//
//  Die frueheren Elemente `Adress-Button` und `ScopeStrip` sind
//  entfallen — beide Aufgaben erledigt jetzt der KontextHeader.
//  Die Legacy-Flags `zeigeAdresseOben` / `zeigeScopeStrip` bleiben
//  als no-ops in der Call-Signatur, damit kein Tab-Screen
//  angefasst werden muss.
//

import SwiftUI

struct AppShellChrome: ViewModifier {
    /// Titel im 30pt-Screen-Block. `nil` lässt den Block weg.
    let titel: String?
    let subtitel: String?
    /// Legacy-Callback fuer den alten Adress-Button. Wird nicht mehr
    /// gerendert — Parameter bleibt, damit Tab-Views nicht umgebaut
    /// werden muessen.
    let onAdresse: () -> Void
    let onEinstellungen: () -> Void
    /// Legacy-Flag (Adress-Button oben) — no-op seit Kontext-Header.
    let zeigeAdresseOben: Bool
    /// Legacy-Flag (farbiger ScopeStrip) — no-op seit Kontext-Header.
    let zeigeScopeStrip: Bool
    /// Optionale zusätzliche Primary-Action rechts neben dem
    /// Einstellungen-Button (z.B. "+" für neue Rechnung).
    let primaryAction: PrimaryAction?

    struct PrimaryAction {
        let symbol: String
        let label: String
        let handler: () -> Void
    }

    func body(content: Content) -> some View {
        content
            // Frame-fuellen VOR .background: sorgt dafuer, dass der
            // bgApp-Hintergrund die komplette verfuegbare Flaeche
            // bedeckt — auch unter einem Scroll-Inhalt, der kuerzer
            // als die Screen-Hoehe ist. Sonst zeigt iOS unten einen
            // schwarzen Streifen zwischen Content-Ende und TabBar.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgApp)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    // Permanenter Kontext-Header (Objekt / Periode /
                    // Wohneinheit-Pills) ist jetzt die EINZIGE
                    // Anzeige des Scope/Periode/Objekts. Der alte
                    // Adress-Button und der farbige ScopeStrip sind
                    // entfallen — sie waren redundant und fuehrten
                    // zum doppelten/dreifachen „Wo bin ich?"-Display.
                    KontextHeader()
                    navBar
                }
                .background(DesignTokens.bgApp)
            }
            // UI-Fix-2 Fix 4a: die letzte Scroll-Zeile soll nicht vom
            // floatenden Inspektor-FAB (48×48 + 72pt bottom padding)
            // verdeckt werden. `contentMargins` schiebt den Scroll-
            // Content nach oben, nicht den Container — TabBar bleibt
            // unberührt.
            .contentMargins(.bottom, 80, for: .scrollContent)
            .navigationBarHidden(true)
    }

    // MARK: - Nav-Bar

    private var navBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Spacer()
                if let primary = primaryAction {
                    Button(action: primary.handler) {
                        Image(systemName: primary.symbol)
                            .font(.title3)
                            .foregroundStyle(DesignTokens.text)
                    }
                    .accessibilityLabel(primary.label)
                    .padding(.trailing, 4)
                }
                Button(action: onEinstellungen) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .accessibilityLabel("Einstellungen")
            }
            if let titel {
                Text(titel)
                    .appFont(AppFont.Basis.displayTitle())
                    .foregroundStyle(DesignTokens.text)
                    .padding(.top, 2)
            }
            if let subtitel {
                Text(subtitel)
                    .appFont(AppFont.Rechnungen.subZeile())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

// MARK: - Convenience-Extension

extension View {
    /// Hängt Navigation-Bar + ScopeStrip an eine Tab-Content-View.
    /// `titel == nil` lässt den 30pt-Titel-Block weg; die Flags
    /// `zeigeAdresseOben` / `zeigeScopeStrip` blenden den Adress-
    /// Button bzw. das farbige Scope-Band aus — sinnvoll für
    /// reduzierte Screens wie den HomeScreen.
    func appShellChrome(
        titel: String?,
        subtitel: String? = nil,
        onAdresse: @escaping () -> Void,
        onEinstellungen: @escaping () -> Void,
        primaryAction: AppShellChrome.PrimaryAction? = nil,
        zeigeAdresseOben: Bool = true,
        zeigeScopeStrip: Bool = true
    ) -> some View {
        modifier(AppShellChrome(
            titel: titel,
            subtitel: subtitel,
            onAdresse: onAdresse,
            onEinstellungen: onEinstellungen,
            zeigeAdresseOben: zeigeAdresseOben,
            zeigeScopeStrip: zeigeScopeStrip,
            primaryAction: primaryAction
        ))
    }
}

