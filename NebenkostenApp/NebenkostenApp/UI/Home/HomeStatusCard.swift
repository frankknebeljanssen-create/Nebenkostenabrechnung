//
//  HomeStatusCard.swift
//  NebenkostenApp — UI/Home
//
//  Kompakte Status-Card unter den Objekt/Einheit-Cards. Zeigt
//  drei bis vier Kennzahlen + prominent den „Nächsten Schritt"
//  (= erste offene Anforderung mit Sprungziel, tappbar über den
//  Router).
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
    /// Tap auf „Nächster Schritt" → Router.
    let onSprung: (Sprungziel) -> Void

    var body: some View {
        Card(tiefe: .erhoben) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Status")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    StatusPill(text: statusKurz, style: statusPillStyle)
                }
                kennzahlenBlock
                if naechsterSchritt != nil {
                    DividerLine()
                    naechsterSchrittZeile
                }
            }
        }
    }

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

    // MARK: - Nächster-Schritt-Zeile

    @ViewBuilder
    private var naechsterSchrittZeile: some View {
        if let anf = naechsterSchritt, let ziel = anf.sprungZiel {
            Button {
                onSprung(ziel)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.accent)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nächster Schritt")
                            .appFont(AppFont.Basis.micro())
                            .foregroundStyle(DesignTokens.textTertiary)
                            .textCase(.uppercase)
                        Text(anf.anforderung.titel)
                            .appFont(AppFont.Abrechnung.kopfName())
                            .foregroundStyle(DesignTokens.text)
                            .multilineTextAlignment(.leading)
                        if let hinweis = anf.hinweis {
                            Text(hinweis)
                                .appFont(AppFont.Basis.caption())
                                .foregroundStyle(DesignTokens.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.top, 6)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Daten-Ableitungen

    private var offeneAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .offen && $0.sprungZiel != nil }
    }

    private var teilweiseAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .teilweise }
    }

    private var naechsterSchritt: AnforderungMitStatus? {
        offeneAnforderungen.first ?? teilweiseAnforderungen.first { $0.sprungZiel != nil }
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
