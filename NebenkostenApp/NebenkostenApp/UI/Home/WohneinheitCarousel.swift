//
//  WohneinheitCarousel.swift
//  NebenkostenApp — UI/Home
//
//  Horizontales Paging zwischen „Gesamtes Objekt" und den
//  einzelnen Wohneinheiten. Ersetzt die frühere
//  `CurrentUnitCard`-Einzelkarte + "Wechseln"-Button —
//  die Auswahl geschieht jetzt direkt per Wisch.
//
//  Index-Mapping (stabil, einzige Wahrheit ist `ScopeManager`):
//    0       → AppScope.objekt         „Gesamtes Objekt"
//    1…N     → AppScope.einheit(id)    sortiert nach Geschoss-Rang
//
//  Beim Erscheinen synchronisiert das Carousel den Index aus dem
//  persistierten Scope; beim Swipen schreibt es den neuen Scope
//  zurück. So greifen die Einheit-Filter in den übrigen Tabs
//  weiterhin wie bisher.
//

import SwiftUI

struct WohneinheitCarousel: View {
    let immobilie: Immobilie
    @Binding var scope: AppScope
    let onOeffnen: (AppScope) -> Void

    /// Cache: der Tab-View-Index wird als eigener State gehalten,
    /// damit SwiftUI kein Thrashing zwischen Scope und Index
    /// macht. Synchronisation passiert in .task / .onChange.
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $index) {
                ForEach(Array(scopeOptionen.enumerated()), id: \.offset) { idx, option in
                    WohneinheitCard(option: option, onTap: { onOeffnen(option.scope) })
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 150)

            if scopeOptionen.count > 1 {
                PaginationDots(anzahl: scopeOptionen.count, aktiv: index)
            }
        }
        .task {
            // Initialer Sync: aus dem persistierten Scope den
            // Index bestimmen.
            index = initialerIndex
        }
        .onChange(of: index) { _, neu in
            guard scopeOptionen.indices.contains(neu) else { return }
            let ziel = scopeOptionen[neu].scope
            if ziel != scope {
                scope = ziel
            }
        }
        .onChange(of: scope) { _, neu in
            // Externer Scope-Wechsel (z.B. über die Einheit-Row
            // in der AbrechnungenView) soll den Carousel mitziehen.
            if let passt = scopeOptionen.firstIndex(where: { $0.scope == neu }),
               passt != index {
                index = passt
            }
        }
    }

    // MARK: - Scope-Optionen

    private var einheiten: [Wohneinheit] {
        ScopeFilter.sichtbareEinheiten(
            alle: immobilie.wohneinheiten ?? [],
            scope: .objekt
        )
    }

    fileprivate struct ScopeOption: Hashable {
        let scope: AppScope
        let titel: String
        let zusatz: String
        let farbe: Color
    }

    fileprivate var scopeOptionen: [ScopeOption] {
        var liste: [ScopeOption] = [
            ScopeOption(
                scope: .objekt,
                titel: "Gesamtes Objekt",
                zusatz: einheitenZusatz,
                farbe: DesignTokens.unitObjekt
            )
        ]
        for e in einheiten {
            liste.append(ScopeOption(
                scope: .einheit(id: e.bezeichnung),
                titel: titelFuer(e),
                zusatz: zusatzFuer(e),
                farbe: ScopeFarbe.farbe(fuer: e)
            ))
        }
        return liste
    }

    private var einheitenZusatz: String {
        let n = einheiten.count
        if n == 0 { return "Noch keine Einheit erfasst" }
        return "Alle \(n) Einheit\(n == 1 ? "" : "en")"
    }

    private func titelFuer(_ e: Wohneinheit) -> String {
        switch e.nutzungsart {
        case .gewerbe:   return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default:         return "\(e.bezeichnung) Wohnung"
        }
    }

    private func zusatzFuer(_ e: Wohneinheit) -> String {
        let mv = (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
        var parts: [String] = []
        if let mv {
            parts.append(ScopeTexte.abkuerzungName(mv.mieterName))
        }
        if e.flaecheM2 > 0 {
            parts.append(Formatting.m2(e.flaecheM2))
        }
        return parts.joined(separator: " · ")
    }

    private var initialerIndex: Int {
        scopeOptionen.firstIndex(where: { $0.scope == scope }) ?? 0
    }
}

// MARK: - Card pro Scope-Option

/// Eine kompakte Card mit identischer Höhe wie die Objekt-Card.
/// Bewusst ohne „Wechseln"-Button: die Auswahl passiert durch
/// Wischen, der Tap öffnet in die Einheit hinein.
fileprivate struct WohneinheitCard: View {
    let option: WohneinheitCarousel.ScopeOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                UnitBalken(farbe: option.farbe)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wohneinheit")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(option.titel)
                        .appFont(AppFont.Abrechnung.kopfName())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    if !option.zusatz.isEmpty {
                        Text(option.zusatz)
                            .appFont(AppFont.Rechnungen.subZeile())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DesignTokens.separatorStrong, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
