//
//  AbrechnungDetailView.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Detail-Sheet für eine einzelne Mieterabrechnung. Angepasst an
//  Design-Handoff (Cards, monoHero, PeriodStatsBlock, StatusPill).
//  Die PDF-Generierung ist hier noch deaktiviert — sie wird in
//  UI-2 über das PDFVorschauSheet angeschlossen.
//
//  Nimmt einen Value-Typ `Mieterabrechnung` entgegen — keine
//  SwiftData-Abhängigkeit. Deshalb lässt sich die View auch in
//  Preview und Tests isoliert instanziieren.
//

import SwiftUI

struct AbrechnungDetailView: View {
    let abrechnung: Mieterabrechnung
    let periode: String
    /// Datenlücken der zugrundeliegenden Periode. Kann Warnungen
    /// (z.B. WMZ-Plausi) enthalten — Blocker tauchen hier nicht
    /// auf, weil der AbrechnungsService bei Blockern bereits wirft.
    var warnungen: [AnforderungMitStatus] = []

    /// PDF-Export-Kontext. Nur wenn diese drei zusammen vorhanden
    /// sind und kein Blocker greift, ist der PDF-Button aktiv.
    /// Phase-0-Previews/Tests ohne Kontext sehen weiterhin "gesperrt".
    var pdfPeriode: Abrechnungsperiode? = nil
    var pdfImmobilie: Immobilie? = nil
    var pdfUser: AppUser? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppShellRouter.self) private var router

    @State private var zeigePDFVorschau = false
    @State private var zeigeMailSheet = false

    /// Defensiver Check: liegt trotz berechneter Mieterabrechnung
    /// noch ein unbehandelter Blocker vor, rendert die View ohne
    /// Saldo-Zahlen und ActionBar-Aktionen. Im normalen Flow tritt
    /// der Fall nicht auf, weil `AbrechnungsService.aggregiere`
    /// schon bei Blockern wirft.
    private var hatBlocker: Bool {
        warnungen.contains { $0.blockiertBerechnung }
    }

    private var pdfExportAktiv: Bool {
        !hatBlocker && pdfPeriode != nil && pdfImmobilie != nil
    }

    /// Mail zusaetzlich an `MailComposer.kannMailSenden` geknuepft —
    /// auf Simulatoren ohne Konto oder frischen Geraeten oeffnet die
    /// Compose-Maske sonst nicht. MFMailCompose ist einzige Mail-API
    /// die Attachments unterstuetzt (`mailto:` kann nur Text).
    private var mailExportAktiv: Bool {
        pdfExportAktiv && MailComposer.kannMailSenden
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !warnungen.isEmpty {
                    warnungenCard
                }
                heroCard
                positionenCard
                saldoCard
                paragraph35aCard
                actionBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .navigationTitle(abrechnung.mieterName.isEmpty ? abrechnung.einheitBezeichnung : ScopeTexte.abkuerzungName(abrechnung.mieterName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .sheet(isPresented: $zeigePDFVorschau) {
            if let p = pdfPeriode, let i = pdfImmobilie {
                PDFVorschauSheet(
                    abrechnung: abrechnung,
                    immobilie: i,
                    periode: p,
                    user: pdfUser
                )
            }
        }
        .sheet(isPresented: $zeigeMailSheet) {
            if let p = pdfPeriode, let i = pdfImmobilie {
                AbrechnungsMailSheet(
                    abrechnung: abrechnung,
                    immobilie: i,
                    periode: p,
                    user: pdfUser
                )
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(periode)
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    StatusPill(text: saldoPillText, style: saldoPillStyle)
                }
                Text(Formatting.euro(abs(abrechnung.saldoEuro)))
                    .appFont(AppFont.monoHero())
                    .foregroundStyle(saldoHeroFarbe)
                Text(saldoHeroLabel)
                    .appFont(AppFont.subtitle())
                    .foregroundStyle(DesignTokens.textSecondary)
                DividerLine().padding(.vertical, 2)
                PeriodStatsBlock(
                    links: StatBlock(
                        label: "Gesamtkosten",
                        wert: Formatting.euro(abrechnung.gesamtkostenEuro),
                        detail: "umlagefähig"
                    ),
                    rechts: StatBlock(
                        label: "Vorauszahlungen",
                        wert: Formatting.euro(abrechnung.vorauszahlungenEuro),
                        detail: "geleistet"
                    )
                )
            }
        }
    }

    // MARK: - Positionen

    private var positionenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Kostenpositionen") {
                Text("\(abrechnung.positionen.count)")
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(abrechnung.positionen.enumerated()), id: \.element.id) { idx, p in
                    positionRow(p)
                    if idx < abrechnung.positionen.count - 1 {
                        DividerLine().padding(.leading, 14)
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

    private func positionRow(_ p: Mieterposition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.kostenart)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                Text(p.verteilerschluesselText)
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatting.euro(p.mieteranteilEuro))
                    .appFont(AppFont.monoBody())
                    .foregroundStyle(DesignTokens.text)
                Text("aus \(Formatting.euro(p.gesamtkostenEuro))")
                    .appFont(AppFont.micro())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Saldo

    private var saldoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Gesamtkosten")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Text(Formatting.euro(abrechnung.gesamtkostenEuro))
                        .appFont(AppFont.monoBody())
                        .foregroundStyle(DesignTokens.text)
                }
                DividerLine()
                HStack {
                    Text("Vorauszahlungen")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Text("\u{2212} \(Formatting.euro(abrechnung.vorauszahlungenEuro))")
                        .appFont(AppFont.monoBody())
                        .foregroundStyle(DesignTokens.text)
                }
                DividerLine()
                HStack(alignment: .firstTextBaseline) {
                    Text("Saldo")
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    Text(Formatting.euro(abrechnung.saldoEuro, showSign: abrechnung.saldoEuro > 0))
                        .appFont(AppFont.monoLarge())
                        .foregroundStyle(saldoHeroFarbe)
                }
            }
        }
    }

    // MARK: - §35a

    @ViewBuilder
    private var paragraph35aCard: some View {
        if abrechnung.steuer35aBetragEuro > 0 {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("§ 35a EStG")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.text)
                        Text("Haushaltsnahe Dienstleistungen / Handwerkerleistungen")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(Formatting.euro(abrechnung.steuer35aBetragEuro))
                        .appFont(AppFont.monoBody())
                        .foregroundStyle(DesignTokens.text)
                }
            }
        }
    }

    // MARK: - Warnungen-Card (Datenlücken, sprungfähig)

    @ViewBuilder
    private var warnungenCard: some View {
        let hatBlockerLokal = hatBlocker
        let ueberschrift = hatBlockerLokal
            ? "Pflichtdaten fehlen"
            : "Hinweise zur Datenlage"
        let akzentFarbe = hatBlockerLokal
            ? DesignTokens.statusError
            : DesignTokens.statusWarn
        let softBg = hatBlockerLokal
            ? DesignTokens.statusErrorSoft
            : DesignTokens.statusWarnSoft

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(akzentFarbe)
                Text(ueberschrift)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(akzentFarbe)
                Spacer()
            }
            ForEach(warnungen) { w in
                warnungsRow(w, akzent: akzentFarbe)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(softBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(akzentFarbe.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func warnungsRow(_ a: AnforderungMitStatus, akzent: Color) -> some View {
        let content = HStack(spacing: 8) {
            StatusDot(status: a.schwere == .blocker ? .error : .warn)
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
            }
            Spacer(minLength: 4)
            if a.sprungZiel != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .contentShape(Rectangle())

        if let ziel = a.sprungZiel {
            Button {
                router.springe(zu: ziel)
                dismiss()
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    // MARK: - ActionBar (PDF / Mail / Drucken)

    private var actionBar: some View {
        VStack(spacing: 8) {
            actionButton(
                titel: pdfButtonTitel,
                symbol: "doc.text.magnifyingglass",
                disabled: !pdfExportAktiv,
                action: { zeigePDFVorschau = true }
            )
            actionButton(
                titel: mailButtonTitel,
                symbol: "envelope",
                disabled: !mailExportAktiv,
                action: { zeigeMailSheet = true }
            )
            actionButton(
                titel: hatBlocker
                    ? "Drucken · gesperrt"
                    : "Drucken (kommt spaeter)",
                symbol: "printer",
                disabled: true,
                action: {}
            )
        }
    }

    private var pdfButtonTitel: String {
        if hatBlocker { return "PDF-Vorschau · gesperrt" }
        if pdfPeriode == nil || pdfImmobilie == nil {
            return "PDF-Vorschau · nicht verfügbar"
        }
        return "PDF-Vorschau"
    }

    private var mailButtonTitel: String {
        if hatBlocker { return "Per Mail versenden · gesperrt" }
        if pdfPeriode == nil || pdfImmobilie == nil {
            return "Per Mail versenden · nicht verfügbar"
        }
        if !MailComposer.kannMailSenden {
            return "Per Mail versenden · kein Mail-Account"
        }
        return "Per Mail versenden"
    }

    private func actionButton(
        titel: String,
        symbol: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(titel)
                    .appFont(AppFont.bodySemi())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(disabled
                             ? DesignTokens.textTertiary
                             : DesignTokens.text)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Saldo-Farben

    private var saldoHeroFarbe: Color {
        if abrechnung.saldoEuro > 0 { return DesignTokens.statusError }
        if abrechnung.saldoEuro < 0 { return DesignTokens.statusOk }
        return DesignTokens.text
    }

    private var saldoHeroLabel: String {
        if abrechnung.saldoEuro > 0 { return "Nachzahlung \(abrechnung.mieterName.isEmpty ? "des Mieters" : abrechnung.mieterName)" }
        if abrechnung.saldoEuro < 0 { return "Erstattung an \(abrechnung.mieterName.isEmpty ? "den Mieter" : abrechnung.mieterName)" }
        return "Ausgeglichen"
    }

    private var saldoPillText: String {
        if abrechnung.saldoEuro > 0 { return "Nachzahlung" }
        if abrechnung.saldoEuro < 0 { return "Erstattung" }
        return "Ausgeglichen"
    }

    private var saldoPillStyle: StatusPill.Style {
        if abrechnung.saldoEuro > 0 { return .error }
        if abrechnung.saldoEuro < 0 { return .ok }
        return .muted
    }
}
