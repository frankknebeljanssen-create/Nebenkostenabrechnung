//
//  EigentuemerUebersichtView.swift
//  NebenkostenApp — UI/Finanzen
//
//  Uebersicht aller `HVAbrechnung`-Entities. Zeigt pro Jahr
//  Aggregate (§35a Handwerker + haushaltsnah, Eigentuemerkosten,
//  Erhaltungsruecklage-Anteil) und pro HV-Abrechnung einen Kopf-
//  Eintrag mit Abrechnungsspitze + Summen. Tap expandiert die
//  Positionen inline.
//
//  Fuer Stufe 2 bewusst kompakt: keine Edit-Funktionen, kein
//  PDF-Anhang-Preview — rein lesende Uebersicht. Erweiterungen
//  (Export, Steuerbericht) folgen separat.
//

import SwiftUI
import SwiftData

struct EigentuemerUebersichtView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HVAbrechnung.abrechnungszeitraumBis, order: .reverse)
    private var abrechnungen: [HVAbrechnung]

    @State private var geoeffneteIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if abrechnungen.isEmpty {
                    leerzustand
                } else {
                    if !jahresAggregate.isEmpty {
                        aggregatBlock
                    }
                    abrechnungsListe
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DesignTokens.bgApp)
        .navigationTitle("Eigentümer-Kosten")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Leerzustand

    @ViewBuilder
    private var leerzustand: some View {
        Card(tiefe: .flach) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text("Noch keine HV-Abrechnung erfasst")
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                }
                Text("Sobald Sie eine Hausverwaltungs-Einzelabrechnung einscannen, sehen Sie hier Ihre nicht umlagefähigen Eigentümerkosten, §35a-Beträge und die Erhaltungsrücklage.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Jahres-Aggregate

    private struct JahresAggregat: Identifiable {
        let jahr: Int
        let handwerker: Decimal
        let haushaltsnah: Decimal
        let eigentuemerKosten: Decimal
        let erhaltungsruecklage: Decimal
        var id: Int { jahr }
    }

    private var jahresAggregate: [JahresAggregat] {
        let kal = Calendar(identifier: .gregorian)
        let gruppiert = Dictionary(grouping: abrechnungen) {
            kal.component(.year, from: $0.abrechnungszeitraumBis)
        }
        return gruppiert
            .map { jahr, liste in
                JahresAggregat(
                    jahr: jahr,
                    handwerker:    liste.reduce(Decimal(0)) { $0 + $1.paragraph35aHandwerkerEuro },
                    haushaltsnah:  liste.reduce(Decimal(0)) { $0 + $1.paragraph35aHaushaltsnahEuro },
                    eigentuemerKosten: liste.reduce(Decimal(0)) {
                        $0 + ($1.eigentuemerKosten ?? []).reduce(Decimal(0)) { $0 + $1.anteilEuro }
                    },
                    erhaltungsruecklage: liste.reduce(Decimal(0)) { $0 + $1.erhaltungsruecklageAnteilEuro }
                )
            }
            .sorted(by: { $0.jahr > $1.jahr })
    }

    @ViewBuilder
    private var aggregatBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JAHRES-SUMMEN")
                .appFont(AppFont.Dashboard.kartenKicker())
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, 4)
            ForEach(jahresAggregate) { j in
                Card(tiefe: .flach, balkenFarbe: DesignTokens.accent) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(j.jahr))
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.text)
                        DividerLine()
                        aggregatZeile(label: "§35a Handwerker", betrag: j.handwerker)
                        aggregatZeile(label: "§35a Haushaltsnahe DL", betrag: j.haushaltsnah)
                        aggregatZeile(label: "Eigentümerkosten", betrag: j.eigentuemerKosten)
                        if j.erhaltungsruecklage > 0 {
                            aggregatZeile(label: "Erhaltungsrücklage-Anteil", betrag: j.erhaltungsruecklage)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func aggregatZeile(label: String, betrag: Decimal) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            Text(Formatting.euro(betrag))
                .appFont(AppFont.monoCaption())
                .foregroundStyle(DesignTokens.text)
        }
    }

    // MARK: - Abrechnungs-Liste

    @ViewBuilder
    private var abrechnungsListe: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALLE HV-ABRECHNUNGEN")
                .appFont(AppFont.Dashboard.kartenKicker())
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            ForEach(abrechnungen) { a in
                abrechnungsCard(a)
            }
        }
    }

    @ViewBuilder
    private func abrechnungsCard(_ a: HVAbrechnung) -> some View {
        let offen = geoeffneteIDs.contains(a.id)
        Card(tiefe: .flach, balkenFarbe: spitzeFarbe(a.abrechnungsspitzeEuro)) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if offen {
                            geoeffneteIDs.remove(a.id)
                        } else {
                            geoeffneteIDs.insert(a.id)
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.hausverwaltungName.isEmpty ? "Hausverwaltung" : a.hausverwaltungName)
                                .appFont(AppFont.bodySemi())
                                .foregroundStyle(DesignTokens.text)
                                .lineLimit(1)
                            Text(zeitraumText(a))
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(a.abrechnungsspitzeEuro < 0 ? "Guthaben" : "Nachzahlung")
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textTertiary)
                            Text(Formatting.euro(abs(a.abrechnungsspitzeEuro)))
                                .appFont(AppFont.monoBetrag17())
                                .foregroundStyle(spitzeFarbe(a.abrechnungsspitzeEuro))
                        }
                        Image(systemName: offen ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if offen {
                    DividerLine()
                    inlineDetail(a)
                }
            }
        }
    }

    @ViewBuilder
    private func inlineDetail(_ a: HVAbrechnung) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // MEA
            if a.meaAnteil > 0 {
                HStack {
                    Text("MEA-Anteil")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    Text("\(a.meaAnteil) / \(a.meaGesamt)")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.text)
                }
            }
            // Vorauszahlungen
            aggregatZeile(label: "Vorauszahlungen lt. Wirtschaftsplan", betrag: a.vorauszahlungenEuro)
            if a.erhaltungsruecklageAnteilEuro > 0 {
                aggregatZeile(label: "Erhaltungsrücklage-Anteil", betrag: a.erhaltungsruecklageAnteilEuro)
            }

            // §35a
            if a.paragraph35aHandwerkerEuro > 0 || a.paragraph35aHaushaltsnahEuro > 0 {
                DividerLine()
                Text("§35A ESTG")
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(DesignTokens.textTertiary)
                if a.paragraph35aHandwerkerEuro > 0 {
                    aggregatZeile(label: "Handwerkerleistungen", betrag: a.paragraph35aHandwerkerEuro)
                }
                if a.paragraph35aHaushaltsnahEuro > 0 {
                    aggregatZeile(label: "Haushaltsnahe DL", betrag: a.paragraph35aHaushaltsnahEuro)
                }
            }

            // Eigentuemer-Positionen
            let eigentuemerListe = a.eigentuemerKosten ?? []
            if !eigentuemerListe.isEmpty {
                DividerLine()
                Text("EIGENTÜMERKOSTEN")
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(DesignTokens.textTertiary)
                ForEach(eigentuemerListe) { pos in
                    aggregatZeile(label: pos.bezeichnung.isEmpty ? "—" : pos.bezeichnung, betrag: pos.anteilEuro)
                }
            }

            // Umlagefaehige-Positionen als Info-Block
            let umlageListe = a.umlagefaehigePositionen ?? []
            if !umlageListe.isEmpty {
                DividerLine()
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.statusOk)
                    Text("AN MIETER WEITERGEREICHT")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.statusOk)
                }
                Text("\(umlageListe.count) umlagefähige Position\(umlageListe.count == 1 ? "" : "en") — als Rechnung\(umlageListe.count == 1 ? "" : "en") im Rechnungen-Tab sichtbar.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func spitzeFarbe(_ betrag: Decimal) -> Color {
        if betrag < 0 { return DesignTokens.statusOk }
        if betrag > 0 { return DesignTokens.statusError }
        return DesignTokens.textSecondary
    }

    private func zeitraumText(_ a: HVAbrechnung) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return "\(f.string(from: a.abrechnungszeitraumVon)) – \(f.string(from: a.abrechnungszeitraumBis))"
    }
}
