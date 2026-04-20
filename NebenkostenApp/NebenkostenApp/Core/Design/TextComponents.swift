//
//  TextComponents.swift
//  NebenkostenApp — Core/Design
//
//  Bausteine für die "Zahlen = Mono, Text = Sans, keine Mischformen
//  in einer Zeile"-Regel aus der Typografie-Spec. Views sollen
//  niemals `Text("Label " + formatierterBetrag)` schreiben — die
//  Schriftart wechselt nicht innerhalb eines String-Literals. Statt
//  dessen gibt es diese Components, die Sans + Mono sauber trennen
//  und immer in der korrekten Spec-Rolle rendern.
//

import SwiftUI

// MARK: - LabelMitBetrag

/// Zwei Text-Views nebeneinander: Label links (Sans), Betrag rechts
/// (Mono). Zwischen beiden ein `Spacer(minLength: 8)`, damit sich der
/// Mono-Betrag bei knappem Platz nicht unter das Label schiebt.
///
/// Die Default-Fonts entsprechen den Rechnungen-Spec-Werten
/// (`issuer` + `betrag`). Call-Sites, die andere Spec-Rollen brauchen
/// (Positions-Label 13/500 + Positions-Betrag Mono 13/600 in
/// Abrechnung-Detail), übergeben die passenden Styles per Parameter.
struct LabelMitBetrag: View {
    let label: String
    let betrag: String
    let labelStyle: AppFontStyle
    let betragStyle: AppFontStyle
    let labelFarbe: Color
    let betragFarbe: Color
    let durchgestrichen: Bool

    init(
        label: String,
        betrag: String,
        labelStyle: AppFontStyle = AppFont.Rechnungen.issuer(),
        betragStyle: AppFontStyle = AppFont.Rechnungen.betrag(),
        labelFarbe: Color = DesignTokens.text,
        betragFarbe: Color = DesignTokens.text,
        durchgestrichen: Bool = false
    ) {
        self.label = label
        self.betrag = betrag
        self.labelStyle = labelStyle
        self.betragStyle = betragStyle
        self.labelFarbe = labelFarbe
        self.betragFarbe = betragFarbe
        self.durchgestrichen = durchgestrichen
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .appFont(labelStyle)
                .foregroundStyle(labelFarbe)
            Spacer(minLength: 8)
            Text(betrag)
                .appFont(betragStyle)
                .foregroundStyle(betragFarbe)
                .strikethrough(durchgestrichen, color: betragFarbe)
        }
    }
}

// MARK: - DatumPeriodeZeile

/// Meta-Zeile "DD.MM.YYYY · DD.MM.YYYY – DD.MM.YYYY" — komplett in
/// Plex Mono gerendert, weil beide Teile numerisch sind. Spec sagt
/// für den Rechnungen-Screen: `Mono 11pt / 400 / textTertiary`.
///
/// Nutzt `Formatting.datum` + `Formatting.periode` (U+2013 EN-DASH
/// zwischen den Perioden-Daten). Der Bullet dazwischen ist ein
/// Interpunct (U+00B7) — für Stellen-Alignment brauchbar, weil er
/// in der Mono-Breite wie eine Ziffer fluchtet.
struct DatumPeriodeZeile: View {
    let rechnungsdatum: Date
    let periodeVon: Date
    let periodeBis: Date
    let style: AppFontStyle
    let farbe: Color

    init(
        rechnungsdatum: Date,
        periodeVon: Date,
        periodeBis: Date,
        style: AppFontStyle = AppFont.Rechnungen.datumPeriode(),
        farbe: Color = DesignTokens.textTertiary
    ) {
        self.rechnungsdatum = rechnungsdatum
        self.periodeVon = periodeVon
        self.periodeBis = periodeBis
        self.style = style
        self.farbe = farbe
    }

    var body: some View {
        Text(zeile)
            .appFont(style)
            .foregroundStyle(farbe)
    }

    private var zeile: String {
        let datum = Formatting.datum(rechnungsdatum)
        if periodeVon == periodeBis {
            return datum
        }
        let periode = Formatting.periode(periodeVon, periodeBis)
        return "\(datum) · \(periode)"
    }
}
