//
//  ScopeIndicatorBar.swift
//  NebenkostenApp — UI/Components
//
//  Schmale Leiste (32pt) unter der NavigationBar. Zeigt auf einen Blick
//  den aktuellen Scope mit Icon, Name und kurzer Kontextinfo. Die Bar
//  ist nicht interaktiv — der Scope-Wechsel passiert über den
//  Titel-Picker oben (ScopePickerToolbar).
//

import SwiftUI

struct ScopeIndicatorBar: View {
    let immobilie: Immobilie

    @Environment(ScopeManager.self) private var scopeManager

    /// View-Modifier-Helper: `.scopeIndicator(immobilie: immobilie)`
    /// hängt die Bar als `.safeAreaInset(edge: .top)` an.
    static func modifier(immobilie: Immobilie) -> some ViewModifier {
        _Modifier(immobilie: immobilie)
    }

    var body: some View {
        guard immobilie.wohneinheiten?.count ?? 0 >= 2 else {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tintFarbe)
                    .frame(width: 18)
                Text(titel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !untertitel.isEmpty {
                    Text("·")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    Text(untertitel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let badge = badgeText {
                    Text(badge)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tintFarbe.opacity(0.20))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(tintFarbe.opacity(0.10))
            .overlay(alignment: .bottom) {
                Rectangle().fill(tintFarbe.opacity(0.35)).frame(height: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Scope: \(titel). \(untertitel)")
        )
    }

    // MARK: - Ableitungen

    private var aktuelleEinheit: Wohneinheit? {
        guard case .einheit(let id) = scopeManager.scope else { return nil }
        return (immobilie.wohneinheiten ?? []).first(where: { $0.bezeichnung == id })
    }

    private var tintFarbe: Color {
        if let e = aktuelleEinheit {
            return ScopeFarbe.farbe(fuer: e)
        }
        return .accentColor
    }

    private var iconName: String {
        if let e = aktuelleEinheit {
            return ScopeFarbe.icon(fuer: e)
        }
        return "house.fill"
    }

    private var titel: String {
        if let e = aktuelleEinheit {
            return e.bezeichnung.isEmpty ? "Einheit" : e.bezeichnung
        }
        return "Gesamt-Objekt"
    }

    private var untertitel: String {
        if let e = aktuelleEinheit {
            let aktiv = (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
            if let mv = aktiv, !mv.mieterName.isEmpty {
                return mv.mieterName
            }
            return e.nutzungsart == .leerstand ? "Leerstand" : ""
        }
        return immobilie.adresse.isEmpty ? "" : immobilie.adresse
    }

    private var badgeText: String? {
        if aktuelleEinheit != nil { return nil }
        let n = immobilie.wohneinheiten?.count ?? 0
        if n <= 1 { return nil }
        return "\(n) Einheiten"
    }
}

// MARK: - ViewModifier

private struct _Modifier: ViewModifier {
    let immobilie: Immobilie
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            ScopeIndicatorBar(immobilie: immobilie)
        }
    }
}

extension View {
    /// Hängt eine ScopeIndicatorBar als `.safeAreaInset(edge: .top)`
    /// an die View. Nur aktiv, wenn das Objekt >=2 Einheiten hat
    /// (sonst zeigt die Bar ohnehin EmptyView).
    func scopeIndicator(immobilie: Immobilie) -> some View {
        modifier(ScopeIndicatorBar.modifier(immobilie: immobilie))
    }
}
