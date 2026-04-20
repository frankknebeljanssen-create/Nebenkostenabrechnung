//
//  ScopeManager+Design.swift
//  NebenkostenApp — Core/App
//
//  Design-Handoff-Erweiterungen: `current` als Alias auf `scope`
//  (im Handoff-Code so benannt) und drei Farb-/Label-Helper für die
//  App-Shell. Alle Farben kommen aus DesignTokens.
//

import SwiftUI

extension ScopeManager {

    /// Handoff-Alias: `current` ↔ `scope`. Neue Views nutzen `current`,
    /// bestehende Phase-0-Views weiter `scope` — identische Semantik.
    var current: AppScope {
        get { scope }
        set { scope = newValue }
    }

    // MARK: - Farb-Helper

    /// Vordergrund-Farbe des aktiven Scope. Objekt-Scope → unitObjekt,
    /// Einheit-Scope → unitKG / unitEG / unitOG je nach Bezeichnung
    /// (Case-insensitive).
    func farbe(_ einheiten: [Wohneinheit] = []) -> Color {
        switch scope {
        case .objekt:
            return DesignTokens.unitObjekt
        case .einheit(let id):
            return einheitFarbe(id: id, einheiten: einheiten, soft: false)
        }
    }

    /// Soft-Farbe (≈12 % Alpha) für ScopeStrip-Background etc.
    func softFarbe(_ einheiten: [Wohneinheit] = []) -> Color {
        switch scope {
        case .objekt:
            return DesignTokens.unitObjektSoft
        case .einheit(let id):
            return einheitFarbe(id: id, einheiten: einheiten, soft: true)
        }
    }

    /// Zwei-Spalten-Label für den ScopeStrip:
    ///   Objekt   → "Objekt · Gesamtes Haus"
    ///   Einheit  → "Einheit · KG Gewerbe" (Mieter-Name falls vorhanden)
    func beschriftung(_ einheiten: [Wohneinheit] = []) -> String {
        switch scope {
        case .objekt:
            return "Objekt · Gesamtes Haus"
        case .einheit(let id):
            let ueber = einheiten.first(where: { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame })
            let mieterName = (ueber?.mietverhaeltnisse ?? [])
                .first(where: { $0.auszugAm == nil })?
                .mieterName ?? ""
            let detail: String
            if !mieterName.isEmpty {
                detail = "\(id) · \(ScopeTexte.abkuerzungName(mieterName))"
            } else {
                detail = nutzungsartLabel(ueber)
            }
            return "Einheit · \(detail)"
        }
    }

    // MARK: - Intern

    private func einheitFarbe(
        id: String,
        einheiten: [Wohneinheit],
        soft: Bool
    ) -> Color {
        // Handoff-Palette: KG/EG/OG sind fest.
        switch id.uppercased() {
        case "KG": return soft ? DesignTokens.unitKGSoft : DesignTokens.unitKG
        case "EG": return soft ? DesignTokens.unitEGSoft : DesignTokens.unitEG
        case "OG": return soft ? DesignTokens.unitOGSoft : DesignTokens.unitOG
        default:
            // Weitere Einheiten (DG, 2.OG, etc.): Fallback auf
            // ScopeFarbe.defaultFarbe (bestehende Farblogik aus
            // Phase 0) + selbst generierter Soft-Overlay.
            let einheit = einheiten.first(where: { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame })
            if let e = einheit {
                let base = ScopeFarbe.farbe(fuer: e)
                return soft ? base.opacity(0.12) : base
            }
            return soft ? DesignTokens.unitObjektSoft : DesignTokens.unitObjekt
        }
    }

    private func nutzungsartLabel(_ e: Wohneinheit?) -> String {
        guard let e else { return "—" }
        switch e.nutzungsart {
        case .wohnung, .einliegerwohnung: return "\(e.bezeichnung) Wohnung"
        case .gewerbe:                    return "\(e.bezeichnung) Gewerbe"
        case .leerstand:                  return "\(e.bezeichnung) Leerstand"
        }
    }
}
