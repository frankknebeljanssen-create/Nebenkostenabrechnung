//
//  AppShellChrome.swift
//  NebenkostenApp — UI/Shell
//
//  ViewModifier für jeden Tab-Content: ersetzt die Standard-
//  Navigation-Bar durch den Handoff-Look mit Adress-Button oben,
//  Plex-Sans-Titel 30 pt darunter und einem 32pt-ScopeStrip. Rechts
//  oben landet per Toolbar der Einstellungen-Button.
//
//  Design-Referenz: design_handoff_nebenkosten_app/assets/shell.jsx
//  (AppNavBar + ScopeStrip).
//

import SwiftUI
import SwiftData

struct AppShellChrome: ViewModifier {
    /// Titel im 30pt-Screen-Block. `nil` lässt den Block weg —
    /// für Screens, die ihre eigene Hauptorientierung (z.B. einen
    /// Perioden-Header) direkt im Content rendern.
    let titel: String?
    let subtitel: String?
    let onAdresse: () -> Void
    let onEinstellungen: () -> Void
    /// Steuert, ob der Adress-Button („Bahnhofstr. 37 ▾") oben
    /// in der NavBar gerendert wird. `false` blendet ihn für
    /// Screens aus, auf denen die Adresse schon anderswo
    /// prominent erscheint (z.B. der HomeScreen mit seinem
    /// Objekt-Carousel).
    let zeigeAdresseOben: Bool
    /// Steuert, ob der ScopeStrip (farbiges Band „OBJEKT · GESAMTES
    /// HAUS") unter der NavBar gerendert wird. `false` blendet ihn
    /// für Screens aus, auf denen der Scope bereits im Content
    /// sichtbar ist (z.B. HomeScreen-WohneinheitCarousel).
    let zeigeScopeStrip: Bool
    /// Optionale zusätzliche Primary-Action rechts neben dem
    /// Einstellungen-Button (z.B. "+" für neue Rechnung).
    let primaryAction: PrimaryAction?

    struct PrimaryAction {
        let symbol: String
        let label: String
        let handler: () -> Void
    }

    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    private var immobilie: Immobilie? {
        immobilien.first
    }

    private var einheiten: [Wohneinheit] {
        immobilie?.wohneinheiten ?? []
    }

    func body(content: Content) -> some View {
        content
            .background(DesignTokens.bgApp)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    // Permanenter Kontext-Header (Objekt / Periode /
                    // Wohneinheit-Pills). Kommt VOR die alte NavBar —
                    // Adress-Button + ScopeStrip bleiben voruebergehend
                    // erhalten, bis die Shell-Konsolidierung in einem
                    // Folge-Task die Redundanz abbaut.
                    KontextHeader()
                    navBar
                    if zeigeScopeStrip {
                        scopeStrip
                    }
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
                if zeigeAdresseOben {
                    Button(action: onAdresse) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                                .font(.system(size: 12, weight: .regular))
                            Text(adresseText)
                                .appFont(AppFont.Rechnungen.adresseBtn())
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .regular))
                        }
                        .foregroundStyle(DesignTokens.textSecondary)
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel("Bereich wählen, aktuell \(scope.beschriftung(einheiten))")
                }
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
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var adresseText: String {
        if let i = immobilie, !i.adresse.isEmpty {
            return i.adresse
        }
        return "Kein Objekt"
    }

    // MARK: - ScopeStrip

    private var scopeStrip: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(scope.farbe(einheiten))
                .frame(width: 8, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(scope.beschriftung(einheiten))
                .appFont(AppFont.Chrome.scopeStreifen())
                .foregroundStyle(scope.farbe(einheiten))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(scope.softFarbe(einheiten))
        .overlay(alignment: .top)    { trenner }
        .overlay(alignment: .bottom) { trenner }
        .contentShape(Rectangle())
        .onTapGesture { onAdresse() }
    }

    private var trenner: some View {
        Rectangle().fill(DesignTokens.separator).frame(height: 0.5)
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

