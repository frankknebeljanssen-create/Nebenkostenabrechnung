//
//  CurrentUnitCard.swift
//  NebenkostenApp — UI/Home
//
//  Zeigt die aktuell aktive Einheit (bzw. "Gesamtes Objekt"
//  wenn der Scope auf `.objekt` steht). Mieter-Name und Fläche
//  als Zusatz, rechts "Wechseln". Linker Farb-Balken in der
//  Scope-Farbe macht den aktuellen Kontext visuell fühlbar.
//

import SwiftUI

struct CurrentUnitCard: View {
    let scope: AppScope
    let immobilie: Immobilie
    /// Callback für „Einheit wechseln" → öffnet ScopePickerSheet.
    let onWechsel: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                UnitBalken(farbe: balkenFarbe)
                    .frame(height: 60)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Aktuelle Wohneinheit")
                            .appFont(AppFont.Dashboard.kartenKicker())
                            .foregroundStyle(DesignTokens.textTertiary)
                        Spacer()
                        wechselnButton
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hauptzeile)
                            .appFont(AppFont.Basis.displayTitle())
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                        if !zusatzZeile.isEmpty {
                            Text(zusatzZeile)
                                .appFont(AppFont.Rechnungen.subZeile())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Ableitung

    private var einheiten: [Wohneinheit] { immobilie.wohneinheiten ?? [] }

    private var aktiveEinheit: Wohneinheit? {
        guard case .einheit(let id) = scope else { return nil }
        return einheiten.first { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame }
    }

    private var aktivesMv: Mietverhaeltnis? {
        (aktiveEinheit?.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private var hauptzeile: String {
        switch scope {
        case .objekt:
            return "Gesamtes Objekt"
        case .einheit:
            guard let e = aktiveEinheit else { return "Einheit nicht verfügbar" }
            return titelFuer(e)
        }
    }

    private var zusatzZeile: String {
        switch scope {
        case .objekt:
            let n = einheiten.count
            return "Alle \(n) Einheit\(n == 1 ? "" : "en")"
        case .einheit:
            guard let e = aktiveEinheit else { return "" }
            var parts: [String] = []
            if let mv = aktivesMv {
                parts.append(ScopeTexte.abkuerzungName(mv.mieterName))
            }
            if e.flaecheM2 > 0 {
                parts.append(Formatting.m2(e.flaecheM2))
            }
            return parts.joined(separator: " · ")
        }
    }

    private var balkenFarbe: Color {
        switch scope {
        case .objekt:
            return DesignTokens.unitObjekt
        case .einheit:
            guard let e = aktiveEinheit else { return DesignTokens.unitObjekt }
            return ScopeFarbe.farbe(fuer: e)
        }
    }

    private func titelFuer(_ e: Wohneinheit) -> String {
        switch e.nutzungsart {
        case .gewerbe: return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default: return "\(e.bezeichnung) Wohnung"
        }
    }

    private var wechselnButton: some View {
        Button {
            onWechsel()
        } label: {
            HStack(spacing: 4) {
                Text("Wechseln")
                    .appFont(AppFont.Rechnungen.rechnungManuellHinzu())
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(DesignTokens.accent)
        }
        .buttonStyle(.plain)
    }
}
