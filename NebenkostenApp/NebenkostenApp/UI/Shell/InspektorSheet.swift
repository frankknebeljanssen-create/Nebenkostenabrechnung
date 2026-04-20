//
//  InspektorSheet.swift
//  NebenkostenApp — UI/Shell
//
//  "Was fehlt noch?"-Sheet für den Floating-?-Button. Zeigt alle
//  AnforderungMitStatus-Einträge der aktuellen Periode gruppiert
//  nach Kategorie (Stammdaten · Zählerstände · Rechnungen ·
//  Plausibilität). Rows mit `sprungZiel != nil` sind tappbar —
//  Tap führt über den `AppShellRouter` direkt zum Korrektur-Ort,
//  das Sheet schließt sich.
//
//  Ersetzt den `InspektorPlatzhalter` aus UI-0. Die Phase-0-
//  `VollstaendigkeitsInspektorSheet` (eigene Datei) bleibt
//  unberührt — sie hängt noch am Phase-0-Debug-Dashboard.
//

import SwiftUI
import SwiftData

struct InspektorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    private var immobilie: Immobilie? { immobilien.first }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted { $0.bis > $1.bis }
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie, let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
    }

    private var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    kopfCard
                    kategorieBlock("Stammdaten",
                                   anforderungen: anforderungenPro(.stammdaten))
                    kategorieBlock("Zählerstände",
                                   anforderungen: anforderungenPro(.zaehlerstand))
                    kategorieBlock("Rechnungen",
                                   anforderungen: anforderungenPro(.rechnung))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle("Was fehlt noch?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Kopf-Card

    private var kopfCard: some View {
        let z = zusammenfassung
        let total = max(1, z.total - z.nichtErwartet)
        let anteil = Double(z.erfuellt) / Double(total)
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Abrechnungsbereitschaft")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Text(Formatting.prozent(anteil, dezimal: 0))
                        .appFont(AppFont.Dashboard.fortschrittProzent())
                        .foregroundStyle(DesignTokens.statusOk)
                }
                ProgressRail(anteil: anteil, fillFarbe: DesignTokens.statusOk)
                HStack(spacing: 16) {
                    stat(label: "Erfüllt", wert: "\(z.erfuellt)", farbe: DesignTokens.statusOk)
                    stat(label: "In Arbeit", wert: "\(z.teilweise)", farbe: DesignTokens.statusWarn)
                    stat(label: "Offen", wert: "\(z.offen)", farbe: DesignTokens.statusError)
                }
            }
        }
    }

    private func stat(label: String, wert: String, farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(AppFont.Dashboard.kpiLabel())
                .foregroundStyle(DesignTokens.textTertiary)
            Text(wert)
                .appFont(AppFont.Dashboard.kpiWert())
                .foregroundStyle(farbe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Kategorie-Block

    @ViewBuilder
    private func kategorieBlock(_ titel: String, anforderungen: [AnforderungMitStatus]) -> some View {
        if !anforderungen.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(titel) {
                    Text(statusKurzText(anforderungen))
                        .appFont(AppFont.Basis.monoSmall())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(anforderungen.enumerated()), id: \.element.id) { idx, a in
                        inspektorRow(a)
                        if idx < anforderungen.count - 1 {
                            DividerLine()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.separator, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func statusKurzText(_ liste: [AnforderungMitStatus]) -> String {
        let erfuellt = liste.filter { $0.status == .erfuellt }.count
        return "\(erfuellt) / \(liste.count)"
    }

    // MARK: - Inspektor-Row

    @ViewBuilder
    private func inspektorRow(_ a: AnforderungMitStatus) -> some View {
        let inhalt = HStack(alignment: .top, spacing: 10) {
            StatusDot(status: dotStatus(a))
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.anforderung.titel)
                    .appFont(AppFont.Basis.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                if let hinweis = a.hinweis {
                    Text(hinweis)
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(3)
                }
                if a.schwere == .warnung {
                    Text("Hinweis · Berechnung läuft")
                        .appFont(AppFont.Basis.micro())
                        .foregroundStyle(DesignTokens.statusWarn)
                }
            }
            Spacer(minLength: 4)
            if a.sprungZiel != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        if let ziel = a.sprungZiel {
            Button {
                router.springe(zu: ziel)
                dismiss()
            } label: { inhalt }
            .buttonStyle(.plain)
        } else {
            inhalt
        }
    }

    private func dotStatus(_ a: AnforderungMitStatus) -> StatusDot.Status {
        switch a.status {
        case .erfuellt:      return .ok
        case .teilweise:     return a.schwere == .warnung ? .warn : .warn
        case .offen:         return a.schwere == .blocker ? .error : .warn
        case .nichtErwartet: return .muted
        }
    }

    // MARK: - Filter

    private func anforderungenPro(_ kat: AnforderungsKategorie) -> [AnforderungMitStatus] {
        anforderungen.filter { $0.anforderung.kategorie == kat }
            .sorted { lhs, rhs in
                // offene vor teilweise vor erfuellt vor nichtErwartet
                let lRank = sortRang(lhs.status)
                let rRank = sortRang(rhs.status)
                if lRank != rRank { return lRank < rRank }
                return lhs.anforderung.titel < rhs.anforderung.titel
            }
    }

    private func sortRang(_ status: AnforderungsStatus) -> Int {
        switch status {
        case .offen:         return 0
        case .teilweise:     return 1
        case .erfuellt:      return 2
        case .nichtErwartet: return 3
        }
    }
}
