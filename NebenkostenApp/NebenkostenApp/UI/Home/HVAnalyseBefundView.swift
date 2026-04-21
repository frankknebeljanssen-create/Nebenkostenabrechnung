//
//  HVAnalyseBefundView.swift
//  NebenkostenApp — UI/Home
//
//  Dedizierter Analyse-Screen fuer HV-Einzelabrechnungen. Wird
//  vom KontextDetailSheet gepusht, wenn die Scan-Extraktion
//  `AnalyseBefund.erkannterTyp == .hvAbrechnung` liefert.
//
//  Layout von oben nach unten:
//
//    Header           — HV-Name, Zeitraum, MEA-Anteil
//    Block A (gruen)  — Umlagefaehige Kosten (werden an Mieter
//                        weitergereicht)
//    Block B (grau)   — Eigentuemerkosten (nicht umlagefaehig)
//    Block C (blau)   — §35a EStG (steuerlich absetzbar)
//    Block D          — Ergebnis (Abrechnungsspitze + VZ)
//    Aktionen         — Abbrechen / Uebernehmen (primaer)
//
//  Der Uebernahme-Flow (Zeichen-Wandlung in HVAbrechnung +
//  HVPosition + HVEigentuemerKosten + N Rechnungen) liegt in
//  KontextDetailSheet; hier nur der Callback-Trigger.
//

import SwiftUI

struct HVAnalyseBefundView: View {
    let rohdaten: HVAbrechnungsRohdaten
    /// Kostenarten der Immobilie — fuer die Darstellung des
    /// Mapping-Vorschlags pro Position. Die tatsaechliche
    /// Kostenart-Zuordnung geschieht beim Uebernehmen.
    let kostenartenDerImmobilie: [String]
    let onUebernehmen: () -> Void
    let onAbbrechen: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                umlagefaehigBlock
                eigentuemerBlock
                paragraph35aBlock
                ergebnisBlock
                aktionsBlock
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DesignTokens.bgApp)
        .navigationTitle("HV-Abrechnung erkannt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", role: .cancel) { onAbbrechen() }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerCard: some View {
        Card(tiefe: .erhoben, balkenFarbe: DesignTokens.accent) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.crop.circle")
                        .foregroundStyle(DesignTokens.accent)
                    Text("HV-ABRECHNUNG")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                if !rohdaten.hausverwaltungName.isEmpty {
                    Text(rohdaten.hausverwaltungName)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                }
                if let zeitraum = zeitraumText {
                    Text(zeitraum)
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                if rohdaten.meaAnteil > 0 {
                    HStack(spacing: 6) {
                        Text("MEA:")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textTertiary)
                        Text(meaText)
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.text)
                    }
                }
                if !rohdaten.wegName.isEmpty || !rohdaten.gebaeudeAdresse.isEmpty {
                    Text([rohdaten.wegName, rohdaten.gebaeudeAdresse]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "))
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Block A — Umlagefaehige Kosten

    @ViewBuilder
    private var umlagefaehigBlock: some View {
        let positionen = rohdaten.umlagefaehigePositionen
        VStack(alignment: .leading, spacing: 8) {
            blockHeader(
                titel: "Umlagefähige Kosten",
                untertitel: "Wird an Mieter weitergereicht",
                symbol: "arrow.right.to.line",
                akzent: DesignTokens.statusOk
            )
            Card(tiefe: .flach, balkenFarbe: DesignTokens.statusOk) {
                VStack(alignment: .leading, spacing: 10) {
                    if positionen.isEmpty {
                        Text("Keine umlagefähigen Positionen erkannt.")
                            .appFont(AppFont.bodyMedium())
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        ForEach(Array(positionen.enumerated()), id: \.element.id) { idx, pos in
                            positionZeile(
                                bezeichnung: pos.bezeichnung,
                                betrkvHinweis: pos.betrkvKostenart,
                                betrag: pos.anteilEuro
                            )
                            if idx < positionen.count - 1 {
                                DividerLine()
                            }
                        }
                        DividerLine()
                        summeZeile(
                            label: "Gesamt umlagefähig",
                            betrag: summeUmlagefaehig,
                            hervorgehoben: true
                        )
                    }
                    Text("Wird beim Übernehmen automatisch als Rechnungen für Ihre Einheit gebucht — Kostenart-Zuordnung laut Claudes Vorschlag.")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.statusOk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Block B — Eigentuemer-Kosten

    @ViewBuilder
    private var eigentuemerBlock: some View {
        let positionen = rohdaten.eigentuemerKosten
        VStack(alignment: .leading, spacing: 8) {
            blockHeader(
                titel: "Ihre Eigentümerkosten",
                untertitel: "Nicht umlagefähig",
                symbol: "person.circle",
                akzent: DesignTokens.textSecondary
            )
            Card(tiefe: .flach, balkenFarbe: DesignTokens.textTertiary) {
                VStack(alignment: .leading, spacing: 10) {
                    if positionen.isEmpty {
                        Text("Keine Eigentümerkosten erkannt.")
                            .appFont(AppFont.bodyMedium())
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        ForEach(Array(positionen.enumerated()), id: \.element.id) { idx, pos in
                            positionZeile(
                                bezeichnung: pos.bezeichnung,
                                betrkvHinweis: nil,
                                betrag: pos.anteilEuro
                            )
                            if idx < positionen.count - 1 {
                                DividerLine()
                            }
                        }
                        DividerLine()
                        summeZeile(
                            label: "Gesamt Eigentümerkosten",
                            betrag: summeEigentuemer,
                            hervorgehoben: true
                        )
                    }
                    Text("Bleiben bei Ihnen — nicht umlagefähig nach §2 BetrKV. Relevant für Ihre eigene Steuererklärung.")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Block C — §35a EStG

    @ViewBuilder
    private var paragraph35aBlock: some View {
        let handwerker = rohdaten.paragraph35aHandwerkerEuro
        let haushaltsnah = rohdaten.paragraph35aHaushaltsnahEuro

        if handwerker > 0 || haushaltsnah > 0 {
            VStack(alignment: .leading, spacing: 8) {
                blockHeader(
                    titel: "§35a EStG",
                    untertitel: "Steuerlich absetzbar",
                    symbol: "percent",
                    akzent: DesignTokens.accent
                )
                Card(tiefe: .flach, balkenFarbe: DesignTokens.accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        if handwerker > 0 {
                            summeZeile(
                                label: "Handwerkerleistungen",
                                betrag: handwerker
                            )
                        }
                        if haushaltsnah > 0 {
                            if handwerker > 0 { DividerLine() }
                            summeZeile(
                                label: "Haushaltsnahe Dienstleistungen",
                                betrag: haushaltsnah
                            )
                        }
                        Text("In Ihrer Einkommensteuererklärung geltend machen. 20 % dieser Beträge werden direkt von der Steuerschuld abgezogen.")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Block D — Ergebnis

    @ViewBuilder
    private var ergebnisBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockHeader(
                titel: "Ergebnis",
                untertitel: abrechnungsspitzeLabel,
                symbol: "equal.square",
                akzent: abrechnungsspitzeFarbe
            )
            Card(tiefe: .erhoben, balkenFarbe: abrechnungsspitzeFarbe) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(abrechnungsspitzeLabel)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer()
                        Text(Formatting.euro(abs(rohdaten.abrechnungsspitzeEuro)))
                            .appFont(AppFont.monoBetrag17())
                            .foregroundStyle(abrechnungsspitzeFarbe)
                    }
                    DividerLine()
                    summeZeile(
                        label: "Vorauszahlungen lt. Wirtschaftsplan",
                        betrag: rohdaten.vorauszahlungenEuro
                    )
                    if rohdaten.erhaltungsruecklageAnteilEuro > 0 {
                        DividerLine()
                        summeZeile(
                            label: "Erhaltungsrücklage-Anteil",
                            betrag: rohdaten.erhaltungsruecklageAnteilEuro
                        )
                    }
                }
            }
        }
    }

    // MARK: - Aktionen

    @ViewBuilder
    private var aktionsBlock: some View {
        VStack(spacing: 10) {
            Button(action: onUebernehmen) {
                aktionLabel(
                    symbol: "checkmark.circle.fill",
                    titel: "Übernehmen",
                    hinweis: "Legt \(rohdaten.umlagefaehigePositionen.count) Rechnung\(rohdaten.umlagefaehigePositionen.count == 1 ? "" : "en") + \(rohdaten.eigentuemerKosten.count) Eigentümerposition\(rohdaten.eigentuemerKosten.count == 1 ? "" : "en") an.",
                    primaer: true
                )
            }
            .buttonStyle(.plain)

            Button(action: onAbbrechen) {
                aktionLabel(
                    symbol: "xmark.circle",
                    titel: "Abbrechen",
                    hinweis: nil,
                    primaer: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper-Views

    @ViewBuilder
    private func blockHeader(
        titel: String,
        untertitel: String,
        symbol: String,
        akzent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(akzent)
                Text(titel.uppercased())
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(akzent)
            }
            Text(untertitel)
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func positionZeile(
        bezeichnung: String,
        betrkvHinweis: String?,
        betrag: Decimal
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bezeichnung.isEmpty ? "—" : bezeichnung)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                if let hinweis = betrkvHinweis, !hinweis.isEmpty {
                    Text("→ \(hinweis)")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer(minLength: 10)
            Text(Formatting.euro(betrag))
                .appFont(AppFont.monoCaption())
                .foregroundStyle(DesignTokens.text)
        }
    }

    @ViewBuilder
    private func summeZeile(
        label: String,
        betrag: Decimal,
        hervorgehoben: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .appFont(hervorgehoben ? AppFont.bodySemi() : AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.text)
            Spacer()
            Text(Formatting.euro(betrag))
                .appFont(hervorgehoben ? AppFont.monoBetrag17() : AppFont.monoCaption())
                .foregroundStyle(DesignTokens.text)
        }
    }

    @ViewBuilder
    private func aktionLabel(
        symbol: String,
        titel: String,
        hinweis: String?,
        primaer: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(primaer ? DesignTokens.accentText : DesignTokens.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(primaer ? DesignTokens.accentText : DesignTokens.text)
                if let hinweis {
                    Text(hinweis)
                        .appFont(AppFont.caption())
                        .foregroundStyle(primaer ? DesignTokens.accentText.opacity(0.8) : DesignTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(primaer ? DesignTokens.accent : DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(primaer ? Color.clear : DesignTokens.separatorStrong, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: primaer ? 10 : 0, y: primaer ? 3 : 0)
    }

    // MARK: - Computed

    private var summeUmlagefaehig: Decimal {
        rohdaten.umlagefaehigePositionen.reduce(Decimal(0)) { $0 + $1.anteilEuro }
    }

    private var summeEigentuemer: Decimal {
        rohdaten.eigentuemerKosten.reduce(Decimal(0)) { $0 + $1.anteilEuro }
    }

    private var zeitraumText: String? {
        guard let von = rohdaten.abrechnungszeitraumVon,
              let bis = rohdaten.abrechnungszeitraumBis else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return "\(f.string(from: von)) – \(f.string(from: bis))"
    }

    private var meaText: String {
        let zaehler = rohdaten.meaAnteil
        let nenner = max(rohdaten.meaGesamt, 1)
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "de_DE")
        nf.groupingSeparator = "."
        nf.numberStyle = .decimal
        let zStr = nf.string(from: NSNumber(value: zaehler)) ?? "\(zaehler)"
        let nStr = nf.string(from: NSNumber(value: nenner)) ?? "\(nenner)"
        return "\(zStr) / \(nStr)"
    }

    private var abrechnungsspitzeFarbe: Color {
        if rohdaten.abrechnungsspitzeEuro < 0 {
            return DesignTokens.statusOk   // Guthaben
        } else if rohdaten.abrechnungsspitzeEuro > 0 {
            return DesignTokens.statusError  // Nachzahlung
        } else {
            return DesignTokens.textSecondary
        }
    }

    private var abrechnungsspitzeLabel: String {
        if rohdaten.abrechnungsspitzeEuro < 0 {
            return "Guthaben für Sie"
        } else if rohdaten.abrechnungsspitzeEuro > 0 {
            return "Nachzahlung an Hausverwaltung"
        } else {
            return "Ausgeglichen"
        }
    }
}
