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
                    WohneinheitCard(
                        option: option,
                        adresse: vollAdresse,
                        onTap: { onOeffnen(option.scope) }
                    )
                    .padding(.vertical, 4)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 132)

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
        /// Nur die Flaeche (z.B. „187 m²") bzw. Aggregat
        /// („Alle 3 Einheiten · 528 m²") — kein Mieter-Name mehr,
        /// der wandert in die Header-Pills.
        let flaeche: String
        let farbe: Color
    }

    fileprivate var scopeOptionen: [ScopeOption] {
        var liste: [ScopeOption] = [
            ScopeOption(
                scope: .objekt,
                titel: "Gesamtes Objekt",
                flaeche: gesamtFlaeche,
                farbe: DesignTokens.unitObjekt
            )
        ]
        for e in einheiten {
            liste.append(ScopeOption(
                scope: .einheit(id: e.bezeichnung),
                titel: titelFuer(e),
                flaeche: flaecheFuer(e),
                farbe: ScopeFarbe.farbe(fuer: e)
            ))
        }
        return liste
    }

    private var gesamtFlaeche: String {
        let n = einheiten.count
        var parts: [String] = []
        if n > 0 {
            parts.append("Alle \(n) Einheit\(n == 1 ? "" : "en")")
        }
        if immobilie.gesamtflaecheM2 > 0 {
            parts.append(Formatting.m2(immobilie.gesamtflaecheM2))
        }
        return parts.isEmpty ? "Noch keine Einheit erfasst" : parts.joined(separator: " · ")
    }

    private func titelFuer(_ e: Wohneinheit) -> String {
        switch e.nutzungsart {
        case .gewerbe:   return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default:         return "\(e.bezeichnung) Wohnung"
        }
    }

    private func flaecheFuer(_ e: Wohneinheit) -> String {
        e.flaecheM2 > 0 ? Formatting.m2(e.flaecheM2) : ""
    }

    /// „Bahnhofstr. 37, 12207 Berlin" — Strasse + Ort auf einer
    /// Zeile. Fehlende Teile werden ausgelassen.
    private var vollAdresse: String {
        let adr = immobilie.adresse.trimmingCharacters(in: .whitespaces)
        let ort = immobilie.ort.trimmingCharacters(in: .whitespaces)
        switch (adr.isEmpty, ort.isEmpty) {
        case (false, false): return "\(adr), \(ort)"
        case (false, true):  return adr
        case (true, false):  return ort
        case (true, true):   return ""
        }
    }

    private var initialerIndex: Int {
        scopeOptionen.firstIndex(where: { $0.scope == scope }) ?? 0
    }
}

// MARK: - Card pro Scope-Option

/// Kompakte Card mit einheitlichem Look zu HomeStatusCard und
/// NaechsterSchrittCard (alle drei nutzen `Card(tiefe: .erhoben,
/// balkenFarbe:)` mit dem aktiven Scope-Farbbalken).
///
/// Inhalte (vertikal): Kicker „WOHNEINHEIT" (14 pt) → Name
/// (18 pt semibold) → Flaeche (13 pt) → Adresse (12 pt). Der
/// Chevron rechts ist entfallen — die gesamte Card ist tappbar
/// und oeffnet die Einstellungen.
fileprivate struct WohneinheitCard: View {
    let option: WohneinheitCarousel.ScopeOption
    let adresse: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card(tiefe: .erhoben, balkenFarbe: option.farbe) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WOHNEINHEIT")
                        .appFont(Self.kickerStyle)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(option.titel)
                        .appFont(Self.nameStyle)
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    if !option.flaeche.isEmpty {
                        Text(option.flaeche)
                            .appFont(AppFont.Rechnungen.subZeile())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                    if !adresse.isEmpty {
                        Text(adresse)
                            .appFont(AppFont.Basis.caption())
                            .foregroundStyle(DesignTokens.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 15 pt / 600 / tracking 0.6 UPPER — Kicker.
    /// +3 pt gegenueber `AppFont.Dashboard.kartenKicker` (12 pt).
    private static let kickerStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 15),
        tracking: 0.6,
        uppercase: true
    )

    /// 19 pt / 600 — Name. +2 pt gegenueber
    /// `AppFont.Abrechnung.kopfName` (17 pt).
    private static let nameStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 19),
        tracking: 0,
        uppercase: false
    )
}
