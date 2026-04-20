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
    let titel: String
    let subtitel: String?
    let onAdresse: () -> Void
    let onEinstellungen: () -> Void

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
                    navBar
                    scopeStrip
                }
                .background(DesignTokens.bgApp)
            }
            .navigationBarHidden(true)
    }

    // MARK: - Nav-Bar

    private var navBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button(action: onAdresse) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2")
                            .font(.system(size: 13, weight: .medium))
                        Text(adresseText)
                            .appFont(AppFont.navAddress())
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.text)
                    .padding(.vertical, 6)
                }
                .accessibilityLabel("Bereich wählen, aktuell \(scope.beschriftung(einheiten))")
                Spacer()
                Button(action: onEinstellungen) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .accessibilityLabel("Einstellungen")
            }
            Text(titel)
                .appFont(AppFont.navTitle())
                .foregroundStyle(DesignTokens.text)
                .padding(.top, 2)
            if let subtitel {
                Text(subtitel)
                    .appFont(AppFont.navSubtitle())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.top, 4)
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
                .frame(width: 10, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(scope.beschriftung(einheiten))
                .appFont(AppFont.scopeStripLabel())
                .foregroundStyle(scope.farbe(einheiten))
                .lineLimit(1)
            Spacer()
            if let flaechenLabel {
                Text(flaechenLabel)
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(scope.farbe(einheiten).opacity(0.85))
            }
            Image(systemName: "arrow.triangle.swap")
                .font(.caption2)
                .foregroundStyle(scope.farbe(einheiten).opacity(0.6))
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
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

    private var flaechenLabel: String? {
        switch scope.current {
        case .objekt:
            let gesamt = immobilie?.gesamtflaecheM2 ?? 0
            guard gesamt > 0 else { return nil }
            return Formatting.fmt(m2: gesamt)
        case .einheit(let id):
            guard let e = einheiten.first(where: { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame }),
                  e.flaecheM2 > 0
            else { return nil }
            return Formatting.fmt(m2: e.flaecheM2)
        }
    }
}

// MARK: - Convenience-Extension

extension View {
    /// Hängt Navigation-Bar + ScopeStrip an eine Tab-Content-View.
    func appShellChrome(
        titel: String,
        subtitel: String? = nil,
        onAdresse: @escaping () -> Void,
        onEinstellungen: @escaping () -> Void
    ) -> some View {
        modifier(AppShellChrome(
            titel: titel,
            subtitel: subtitel,
            onAdresse: onAdresse,
            onEinstellungen: onEinstellungen
        ))
    }
}

// MARK: - Fläche-Formatter (kleiner Add-on zu Formatting)

extension Formatting {
    static func fmt(m2: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.groupingSeparator = "."
        let s = f.string(from: NSDecimalNumber(decimal: m2)) ?? "0"
        return "\(s) m²"
    }
}
