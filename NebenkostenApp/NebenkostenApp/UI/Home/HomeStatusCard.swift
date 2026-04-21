//
//  HomeStatusCard.swift
//  NebenkostenApp — UI/Home
//
//  Kompakte Status-Card unter den Objekt/Einheit-Cards. Zeigt
//  drei bis vier Kennzahlen + Status-Pill zum Periodenzustand.
//
//  Der "Naechste Schritt" lebt nach Home-Refactor als eigene
//  `NaechsterSchrittCard` unterhalb — gleich gewichtet, gleiche
//  Breite wie die uebrigen Home-Cards.
//
//  Kein Dashboard — nur die wichtigsten, sofort erfassbaren Infos.
//  Alle Zahlen kommen aus VollstaendigkeitsPruefung der aktiven
//  Periode.
//

import SwiftUI

struct HomeStatusCard: View {
    let anforderungen: [AnforderungMitStatus]
    let immobilie: Immobilie
    let periode: Abrechnungsperiode?
    /// Farbiger Balken links — matches den aktiven Scope und
    /// ordnet die Card visuell in die Home-Karten-Gruppe
    /// (Wohneinheit, Status, Naechster Schritt) ein.
    let balkenFarbe: Color

    var body: some View {
        Card(tiefe: .erhoben, balkenFarbe: balkenFarbe) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Status")
                        .appFont(Self.kickerStyle)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    StatusPill(text: statusKurz, style: statusPillStyle)
                }
                kennzahlenBlock
            }
        }
    }

    /// 14 pt / 600 / tracking 0.6 UPPER — Kicker. +2 pt gegenueber
    /// `AppFont.Dashboard.kartenKicker` (12 pt). Identisch zum
    /// Kicker in `NaechsterSchrittCard` — beide Home-Cards teilen
    /// sich dieselbe Typografie-Rolle.
    private static let kickerStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 14),
        tracking: 0.6,
        uppercase: true
    )

    // MARK: - Kennzahlen

    private var kennzahlenBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            kennzahlZeile(
                label: "Zählerstände",
                wert: zaehlerTextPaar.links,
                detail: zaehlerTextPaar.rechts
            )
            kennzahlZeile(
                label: "Rechnungen geprüft",
                wert: rechnungenTextPaar.links,
                detail: rechnungenTextPaar.rechts
            )
            kennzahlZeile(
                label: "Dokumente",
                wert: dokumenteZeile,
                detail: nil
            )
        }
    }

    private func kennzahlZeile(label: String, wert: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .appFont(AppFont.Basis.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(AppFont.Dashboard.einheitVorauszahlung())
                .foregroundStyle(DesignTokens.text)
            if let detail {
                Text("· \(detail)")
                    .appFont(AppFont.Basis.smallCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
    }

    // MARK: - Daten-Ableitungen

    private var offeneAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .offen && $0.sprungZiel != nil }
    }

    private var teilweiseAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .teilweise }
    }

    private var zaehlerAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.anforderung.kategorie == .zaehlerstand
                && $0.anforderung.id != "plausi-wmz"
        }
    }

    private var zaehlerTextPaar: (links: String, rechts: String?) {
        let total = zaehlerAnforderungen.count
        let erfuellt = zaehlerAnforderungen.filter { $0.status == .erfuellt }.count
        let offen = zaehlerAnforderungen.filter { $0.status == .offen }.count
        if total == 0 { return ("—", nil) }
        return (
            "\(erfuellt) / \(total)",
            offen > 0 ? "\(offen) fehlen" : nil
        )
    }

    private var rechnungsAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.anforderung.kategorie == .rechnung }
    }

    private var rechnungenTextPaar: (links: String, rechts: String?) {
        let total = rechnungsAnforderungen.count
        let erfuellt = rechnungsAnforderungen.filter { $0.status == .erfuellt }.count
        if total == 0 { return ("—", nil) }
        let teilweise = rechnungsAnforderungen.filter { $0.status == .teilweise }.count
        return (
            "\(erfuellt) / \(total)",
            teilweise > 0 ? "\(teilweise) in Arbeit" : nil
        )
    }

    private var dokumenteZeile: String {
        let alle = (immobilie.rechnungen ?? []).count
        return alle == 0 ? "Noch keine" : "\(alle) erfasst"
    }

    private var statusKurz: String {
        guard periode != nil else { return "Keine Periode" }
        let offen = offeneAnforderungen.count
        let teil = teilweiseAnforderungen.count
        if offen == 0 && teil == 0 { return "Bereit" }
        if offen == 0 { return "In Arbeit" }
        return "Daten fehlen"
    }

    private var statusPillStyle: StatusPill.Style {
        guard periode != nil else { return .muted }
        let offen = offeneAnforderungen.count
        let teil = teilweiseAnforderungen.count
        if offen == 0 && teil == 0 { return .ok }
        if offen == 0 { return .warn }
        return .error
    }
}
