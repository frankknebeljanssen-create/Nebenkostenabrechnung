//
//  AnalyseBefundView.swift
//  NebenkostenApp — UI/Home
//
//  Vollflaechiger Screen — KEIN Modal — der nach jedem Scan im
//  KontextDetailSheet auftaucht. Drei Bloecke von oben nach unten:
//
//    Block 1 — Was wurde erkannt
//    Block 2 — Was fehlt noch
//    Block 3 — Aktionen (weiter scannen / manuell / uebernehmen)
//
//  Widersprueche (Block 4, optional) erscheinen direkt unter
//  Block 1, wenn welche vorliegen.
//
//  Wird als NavigationLink-Ziel aus dem KontextDetailSheet heraus
//  gepusht — der User kann mit dem System-„Zurueck" zur
//  Detail-Ansicht zurueck, ohne aus dem Flow zu fallen.
//

import SwiftUI

struct AnalyseBefundView: View {
    @Bindable var sitzung: AnalyseSitzung
    let onWeiterScannen: () -> Void
    let onManuellEintragen: () -> Void
    let onUebernehmen: () -> Void
    let onAbbrechen: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                erkanntBlock
                if !sitzung.widersprueche.isEmpty {
                    widerspruchBlock
                }
                fehltBlock
                aktionsBlock
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DesignTokens.bgApp)
        .navigationTitle("Analyse-Ergebnis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen", role: .cancel) { onAbbrechen() }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        Card(tiefe: .erhoben, balkenFarbe: DesignTokens.accent) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let typ = sitzung.letzterBefund?.erkannterTyp {
                        Image(systemName: typ.icon)
                            .foregroundStyle(DesignTokens.accent)
                        Text(typ.anzeige.uppercased())
                            .appFont(AppFont.Dashboard.kartenKicker())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                Text("Scan \(sitzung.scanAnzahl) von \(sitzung.scanAnzahl) · \(sitzung.einheitBezeichnung)")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                let typen = sitzung.dokumentTypen.map(\.anzeige).joined(separator: " · ")
                if !typen.isEmpty {
                    Text(typen)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    // MARK: - Block 1 — Erkannt

    @ViewBuilder
    private var erkanntBlock: some View {
        let felder = sitzung.erkannteFelderSortiert()
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderZeile(
                titel: "Was wurde erkannt",
                anzahl: felder.count
            )
            if felder.isEmpty {
                Card {
                    Text("Noch keine Felder erkannt.")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(felder.enumerated()), id: \.element.id) { idx, feld in
                            ErkanntZeile(feld: feld)
                            if idx < felder.count - 1 {
                                DividerLine()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Widerspruchs-Block

    @ViewBuilder
    private var widerspruchBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderZeile(
                titel: "Widersprüche",
                anzahl: sitzung.widersprueche.count,
                farbe: DesignTokens.statusError
            )
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sitzung.widersprueche) { w in
                        WiderspruchZeile(widerspruch: w)
                    }
                }
            }
        }
    }

    // MARK: - Block 2 — Fehlt

    @ViewBuilder
    private var fehltBlock: some View {
        let alle = sitzung.letzterBefund?.fehlendeDaten ?? []
        let wichtig = alle.filter { $0.kategorie == .wichtig }
        let empfohlen = alle.filter { $0.kategorie == .empfohlen }
        let optional = alle.filter { $0.kategorie == .optional }

        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderZeile(
                titel: "Was fehlt noch",
                anzahl: alle.count
            )
            if alle.isEmpty {
                Card {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.statusOk)
                        Text("Alle Pflichtfelder vorhanden.")
                            .appFont(AppFont.bodyMedium())
                            .foregroundStyle(DesignTokens.text)
                    }
                }
            } else {
                if !wichtig.isEmpty {
                    fehltGruppe(titel: "Wichtig", eintraege: wichtig, farbe: DesignTokens.statusError, symbol: "xmark.circle.fill")
                }
                if !empfohlen.isEmpty {
                    fehltGruppe(titel: "Empfohlen", eintraege: empfohlen, farbe: DesignTokens.statusWarn, symbol: "circle.lefthalf.filled")
                }
                if !optional.isEmpty {
                    fehltGruppe(titel: "Optional", eintraege: optional, farbe: DesignTokens.textTertiary, symbol: "circle")
                }
            }
        }
    }

    @ViewBuilder
    private func fehltGruppe(titel: String, eintraege: [FehlendeDaten], farbe: Color, symbol: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(titel.uppercased())
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(farbe)
                ForEach(Array(eintraege.enumerated()), id: \.element.id) { idx, e in
                    FehltZeile(eintrag: e, farbe: farbe, symbol: symbol)
                    if idx < eintraege.count - 1 {
                        DividerLine()
                    }
                }
            }
        }
    }

    // MARK: - Block 3 — Aktionen

    @ViewBuilder
    private var aktionsBlock: some View {
        VStack(spacing: 10) {
            Button(action: onWeiterScannen) {
                aktionsLabel(symbol: "doc.text.viewfinder", titel: "Weiteres Dokument scannen", hinweis: "Fügt zum gleichen Kontext hinzu.")
            }
            .buttonStyle(.plain)

            Button(action: onManuellEintragen) {
                aktionsLabel(symbol: "keyboard", titel: "Fehlende Felder manuell eintragen", hinweis: nil)
            }
            .buttonStyle(.plain)

            Button(action: onUebernehmen) {
                aktionsLabel(
                    symbol: "checkmark.circle.fill",
                    titel: "So übernehmen",
                    hinweis: "Rest kann später ergänzt werden.",
                    primaer: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func aktionsLabel(symbol: String, titel: String, hinweis: String?, primaer: Bool = false) -> some View {
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
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(primaer ? DesignTokens.accentText.opacity(0.8) : DesignTokens.textTertiary)
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
}

// MARK: - Section-Header-Zeile

private struct SectionHeaderZeile: View {
    let titel: String
    let anzahl: Int
    var farbe: Color = DesignTokens.textSecondary

    var body: some View {
        HStack(spacing: 8) {
            Text(titel.uppercased())
                .appFont(AppFont.Dashboard.kartenKicker())
                .foregroundStyle(farbe)
            Text("\(anzahl)")
                .appFont(AppFont.monoCaption())
                .foregroundStyle(DesignTokens.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Erkannt-Zeile

private struct ErkanntZeile: View {
    let feld: ErkanntesFeld

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: feld.warnung != nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(feld.warnung != nil ? DesignTokens.statusWarn : DesignTokens.statusOk)
                Text(feld.label)
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(width: 120, alignment: .leading)
                Text(feld.wert)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let altWert = feld.altWert {
                HStack(spacing: 6) {
                    Spacer().frame(width: 24)
                    Text("aktualisiert durch \(feld.quelle), vorher: \(altWert)")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.statusWarn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 6) {
                    Spacer().frame(width: 24)
                    Text("aus \(feld.quelle)")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textTertiary)
                    if let w = feld.warnung {
                        Text("· \(w)")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.statusWarn)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Fehlt-Zeile

private struct FehltZeile: View {
    let eintrag: FehlendeDaten
    let farbe: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(farbe)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.titel)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                if let h = eintrag.hinweis {
                    Text(h)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                if let typ = eintrag.empfohlenerTyp {
                    HStack(spacing: 4) {
                        Image(systemName: typ.icon)
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.textTertiary)
                        Text(typ.anzeige)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Widerspruch-Zeile

private struct WiderspruchZeile: View {
    let widerspruch: Widerspruch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.statusError)
                Text(widerspruch.feld)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
            }
            ForEach(widerspruch.varianten) { v in
                HStack(spacing: 10) {
                    Circle()
                        .stroke(DesignTokens.textTertiary, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    Text(v.wert)
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.text)
                    Text("· \(v.quelle)")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                }
            }
        }
    }
}
