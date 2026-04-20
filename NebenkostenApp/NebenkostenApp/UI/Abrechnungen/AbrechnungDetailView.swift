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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                positionenCard
                saldoCard
                paragraph35aCard
                pdfButton
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

    // MARK: - PDF

    private var pdfButton: some View {
        Button {
            // PDF-Vorschau wird in UI-2 als Sheet integriert.
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                Text("PDF-Vorschau (kommt in UI-2)")
                    .appFont(AppFont.bodySemi())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(DesignTokens.textTertiary)
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
        .disabled(true)
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
